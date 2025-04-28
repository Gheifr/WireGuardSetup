WireGuard Server на Ubuntu (Oracle Cloud)
Зміст
Установка WireGuard

Налаштування сервера

Створення ключів для клієнтів

Приклад файлів конфігурації

Додатково

Установка WireGuard
Оновити систему:

bash
Копіювати
Редагувати
sudo apt update && sudo apt upgrade -y
Встановити WireGuard:

bash
Копіювати
Редагувати
sudo apt install wireguard -y
Створити директорію для ключів:

bash
Копіювати
Редагувати
mkdir ~/wireguard-keys
Згенерувати серверні ключі:

bash
Копіювати
Редагувати
umask 077
wg genkey | tee ~/wireguard-keys/privatekey | wg pubkey > ~/wireguard-keys/publickey
Встановити права доступу на ключі:

bash
Копіювати
Редагувати
chmod 600 ~/wireguard-keys/*
Створити директорію та файл конфігурації сервера:

bash
Копіювати
Редагувати
sudo mkdir -p /etc/wireguard
sudo nano /etc/wireguard/wg0.conf
Відкрити порт у фаєрволі (якщо UFW активний):

bash
Копіювати
Редагувати
sudo ufw allow 51820/udp
Увімкнути IP forwarding:

Відкрити конфігураційний файл:

bash
Копіювати
Редагувати
sudo nano /etc/sysctl.conf
Розкоментувати або додати рядок:

ini
Копіювати
Редагувати
net.ipv4.ip_forward=1
Застосувати зміни:

bash
Копіювати
Редагувати
sudo sysctl -p
Запустити WireGuard та додати у автозапуск:

bash
Копіювати
Редагувати
sudo systemctl start wg-quick@wg0
sudo systemctl enable wg-quick@wg0
Налаштування сервера
Секція [Interface]
ini
Копіювати
Редагувати
[Interface]
Address = 10.8.0.1/24   # Тунельна IP-адреса сервера
PrivateKey = <серверний_приватний_ключ>
ListenPort = 62120      # Порт для прослуховування
SaveConfig = false      # Зберігати чи ні зміни у конфігу при зупинці/запуску

# Налаштування iptables для Oracle Cloud (адаптувати інтерфейс ens3 за потребою)
PostUp = iptables -I FORWARD -i ens3 -o wg0 -j ACCEPT; iptables -I FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE; iptables -I INPUT -i ens3 -p udp --dport 62120 -m state --state NEW,ESTABLISHED -j ACCEPT
PostDown = iptables -D FORWARD -i ens3 -o wg0 -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE; iptables -D INPUT -i ens3 -p udp --dport 62120 -m state --state NEW,ESTABLISHED -j ACCEPT
🔥 Примітка:
Для інших хмарних платформ інтерфейс (ens3) або правила iptables можуть бути іншими.

Секція [Peer] (клієнти)
ini
Копіювати
Редагувати
[Peer]
PublicKey = <публічний_ключ_клієнта>
AllowedIPs = 10.8.0.2/32
Для кожного клієнта додається окрема секція [Peer].

Створення ключів для клієнтів
Згенерувати ключі для нового клієнта:

bash
Копіювати
Редагувати
wg genkey | tee ~/wireguard-keys/client_privatekey | wg pubkey > ~/wireguard-keys/client_publickey
📌 Рекомендація:
Іменуйте ключі так, щоб зрозуміти, для кого вони:
Наприклад:

bash
Копіювати
Редагувати
wg genkey | tee ~/wireguard-keys/0.2.laptop_privatekey | wg pubkey > ~/wireguard-keys/0.2.laptop_publickey
Приклад файлів конфігурації
Сервер /etc/wireguard/wg0.conf
ini
Копіювати
Редагувати
[Interface]
Address = 10.8.0.1/24
PrivateKey = <серверний_приватний_ключ>
ListenPort = 62120
SaveConfig = false
PostUp = iptables -I FORWARD -i ens3 -o wg0 -j ACCEPT; iptables -I FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE; iptables -I INPUT -i ens3 -p udp --dport 62120 -m state --state NEW,ESTABLISHED -j ACCEPT
PostDown = iptables -D FORWARD -i ens3 -o wg0 -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE; iptables -D INPUT -i ens3 -p udp --dport 62120 -m state --state NEW,ESTABLISHED -j ACCEPT

[Peer]
PublicKey = <публічний_ключ_клієнта_1>
AllowedIPs = 10.8.0.2/32

[Peer]
PublicKey = <публічний_ключ_клієнта_2>
AllowedIPs = 10.8.0.3/32
Клієнт client.conf
ini
Копіювати
Редагувати
[Interface]
Address = 10.8.0.2/32
PrivateKey = <приватний_ключ_клієнта>

[Peer]
PublicKey = <публічний_ключ_сервера>
Endpoint = <публічна_IP_адреса_сервера>:62120
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
Додатково
Перевірка конфігурації перед запуском:

bash
Копіювати
Редагувати
sudo wg-quick check wg0
Перевірка статусу підключення:

bash
Копіювати
Редагувати
sudo wg
Генерація QR-коду для підключення (зручніше для смартфонів):

Встановити:

bash
Копіювати
Редагувати
sudo apt install qrencode
Згенерувати QR-код:

bash
Копіювати
Редагувати
qrencode -t ansiutf8 < /шлях/до/конфіг_клієнта.conf
✅ Готово! WireGuard налаштований!