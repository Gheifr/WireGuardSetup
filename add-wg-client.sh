#!/bin/bash

# Функція для перевірки помилок
check_error() {
    if [ $? -ne 0 ]; then
        echo "Помилка: $1"
        exit 1
    fi
}

# Функція для валідації IP-адреси
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Некоректна IP-адреса"
        exit 1
    fi
    
    IFS='.' read -r -a ip_segments <<< "$ip"
    for segment in "${ip_segments[@]}"; do
        if [[ $segment -gt 255 ]]; then
            echo "Некоректна IP-адреса: сегмент не може бути більше 255"
            exit 1
        fi
    done
}

# Перевірка наявності потрібних директорій
mkdir -p ${HOME}/wireguard-keys ${HOME}/wireguard-configs
check_error "Не вдалося створити необхідні директорії"

# Отримання даних від користувача
read -p 'IP-адреса: ' ip_address
validate_ip "$ip_address"

read -p 'Назва пристрою: ' device
if [[ -z "$device" ]]; then
    echo "Назва пристрою не може бути порожньою"
    exit 1
fi

read -p 'Потрібен QR-код? (y/n): ' is_qr_code
is_qr_code=$(echo "$is_qr_code" | tr '[:upper:]' '[:lower:]')

# Формування назви клієнта (останній октет IP + назва пристрою)
last_octet=$(echo "$ip_address" | cut -d '.' -f 4)
client_name="${last_octet}.${device}"
echo "Створення конфігурації для клієнта: $client_name"

# Генерація ключів для нового пристрою
echo "Генерація ключів..."
wg genkey | tee ${HOME}/wireguard-keys/${client_name}_privatekey | wg pubkey > ${HOME}/wireguard-keys/${client_name}_publickey
check_error "Не вдалося згенерувати ключі Wireguard"

# Зчитування згенерованих ключів
dev_pub_key=$(cat ${HOME}/wireguard-keys/${client_name}_publickey)
check_error "Не вдалося прочитати публічний ключ"
dev_pr_key=$(cat ${HOME}/wireguard-keys/${client_name}_privatekey)
check_error "Не вдалося прочитати приватний ключ"

# Обмеження доступу до ключів
chmod 600 ${HOME}/wireguard-keys/${client_name}_privatekey
chmod 600 ${HOME}/wireguard-keys/${client_name}_publickey

# Зчитування публічного ключа сервера з конфігураційного файлу
# (альтернатива жорстко закодованому ключу)
SERVER_CONFIG="/etc/wireguard/wg0.conf"
if [[ -f "$SERVER_CONFIG" ]]; then
    server_private_key=$(grep -A 1 "\[Interface\]" "$SERVER_CONFIG" | grep "PrivateKey" | cut -d '=' -f2 | xargs)
    server_pub_key=$(echo "$server_private_key" | wg pubkey)
    if [[ -z "$server_pub_key" ]]; then
        echo "Не вдалося отримати публічний ключ сервера."
        exit 1
    fi
fi

# Отримання зовнішньої IP-адреси сервера
echo "Визначення зовнішньої IP-адреси сервера..."
server_ip=$(curl -s ifconfig.me)
if [[ -z "$server_ip" ]]; then
    echo "Не вдалося визначити зовнішню IP-адресу. Будь ласка, введіть її вручну:"
    read -p 'Зовнішня IP-адреса сервера: ' server_ip
fi

# Перевірка на наявність ip в серверному конфігу
if grep -q "$ip_address/32" "$SERVER_CONFIG"; then
    echo "Цей IP (${ip_address}/32) вже існує в конфігурації сервера!"
    read -p "Додати повторно? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Операцію скасовано."
        exit 1
    fi
fi

# Перевірка наявності ключа в серверному конфігу
if grep -q "$dev_pub_key" "$SERVER_CONFIG"; then
    echo "Цей публічний ключ вже доданий до конфігу!"
    read -p "Додати повторно? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "Операцію скасовано."
        exit 1
    fi
fi

# Формування секції конфігурації сервера
svr_config_section="[Peer]
PublicKey = ${dev_pub_key}
AllowedIPs = ${ip_address}/32"

# Додавання секції в конфігурацію сервера
echo -e "\n\n${svr_config_section}" | sudo tee -a "$SERVER_CONFIG"
check_error "Не вдалося оновити конфігурацію сервера"

# Створення та запис файлу конфігурації клієнта
client_config="[Interface]
Address = ${ip_address}/32
PrivateKey = ${dev_pr_key}
DNS = 8.8.8.8

[Peer]
PublicKey = ${server_pub_key}
Endpoint = ${server_ip}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25"

echo -e "$client_config" > ${HOME}/wireguard-configs/${client_name}.conf
check_error "Не вдалося створити файл конфігурації клієнта"

# Створення QR-коду, якщо потрібно
if [[ "$is_qr_code" == "y" ]]; then
    echo "Створення QR-коду..."
    qrencode -o ${HOME}/wireguard-configs/${client_name}.png -r ${HOME}/wireguard-configs/${client_name}.conf
    check_error "Не вдалося створити QR-код"
    echo "QR-код збережено у ${HOME}/wireguard-configs/${client_name}.png"
fi

# Додати клієнта в лог
echo "$client_name - $ip_address" >> ${HOME}/wireguard-configs/clients.log

# Перезапуск служби Wireguard
echo "Перезапуск Wireguard..."
sudo systemctl restart wg-quick@wg0
check_error "Не вдалося перезапустити Wireguard"

echo "Готово! Конфігурація клієнта збережена у ${HOME}/wireguard-configs/${client_name}.conf"