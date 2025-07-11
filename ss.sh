#!/bin/bash

# Функция для проверки успешности выполнения команды
check_success() {
    if [ $? -ne 0 ]; then
        echo "Ошибка выполнения команды. Прерывание скрипта."
        exit 1
    fi
}

# Функция для проверки статуса службы
check_service_status() {
    local service_name="shadowsocks-libev-server@config"
    local status=$(systemctl is-active "$service_name")
    
    if [ "$status" == "active" ]; then
        echo -e "\033[0;32mShadowsocks работает успешно: статус active (running)\033[0m"
    else
        echo -e "\033[0;31mОшибка: Shadowsocks не работает. Статус: $status\033[0m"
        exit 1
    fi
}

# Функция для проверки пинга и обновления /etc/hosts
check_ping_and_update_hosts() {
    local ips="13.225.164.218 13.227.61.59 143.204.127.42 13.35.51.41 99.84.58.138 18.65.193.131 18.65.176.132 99.84.140.147 13.225.173.96 54.240.188.143 13.35.55.41 18.65.207.131 18.65.212.131"
    local min_avg_ping=999999
    local best_ip=""
    local min_ping=999999
    local max_ping=999999

    echo "Проверка пинга для IP-адресов..."
    ping_output=$(fping -a -A -c 3 $ips 2>&1)

    echo "$ping_output"

    while IFS= read -r line; do
        if [[ $line =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]; then
            ip="${BASH_REMATCH[1]}"
            if [[ $line =~ min/avg/max\ =\ ([0-9]+)\/([0-9]+)\/([0-9]+) ]]; then
                current_min_ping="${BASH_REMATCH[1]}"
                avg_ping="${BASH_REMATCH[2]}"
                current_max_ping="${BASH_REMATCH[3]}"
                echo "Пинг для $ip: min=$current_min_ping ms, avg=$avg_ping ms, max=$current_max_ping ms"
                
                if (( avg_ping < min_avg_ping )) || { (( avg_ping == min_avg_ping )) && (( current_min_ping < min_ping )); } || { (( avg_ping == min_avg_ping )) && (( current_min_ping == min_ping )) && (( current_max_ping < max_ping )); }; then
                    min_avg_ping=$avg_ping
                    min_ping=$current_min_ping
                    max_ping=$current_max_ping
                    best_ip=$ip
                fi
            fi
        fi
    done <<< "$ping_output"

    if [ -n "$best_ip" ]; then
        echo -e "\033[0;32mВыбранный IP: $best_ip с минимальным пингом: avg=$min_avg_ping ms, min=$min_ping ms, max=$max_ping ms\033[0m"
        # Удаление старых записей с fapi.binance.com из /etc/hosts
        sudo sed -i '/fapi.binance.com/d' /etc/hosts
        check_success
        sudo sed -i '/api.binance.com/d' /etc/hosts
        check_success
        echo "$best_ip fapi.binance.com" | sudo tee -a /etc/hosts > /dev/null
        check_success
        echo "$best_ip api.binance.com" | sudo tee -a /etc/hosts > /dev/null
        check_success
    else
        echo -e "\033[0;31mНе удалось определить лучший IP\033[0m"
        exit 1
    fi
}

# Запрос порта у пользователя и установка значения по умолчанию, если ввод пустой
read -p "Введите порт для Shadowsocks (по умолчанию 8388): " SERVER_PORT
SERVER_PORT="${SERVER_PORT:-8388}"
echo

# Запрос пароля у пользователя и установка значения по умолчанию, если ввод пустой
read -sp "Введите пароль для Shadowsocks(по умолчанию 123456): " PASSWORD
PASSWORD="${PASSWORD:-123456}"
echo

# Параметры
METHOD="aes-256-gcm"
CONFIG_FILE="/var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json"

# Обновление списка пакетов
echo "Обновление списка пакетов."
apt update
check_success

# Установка необходимых пакетов
if ! command -v fping &> /dev/null; then
    echo "Устанавливаем fping..."
    sudo apt-get install -y fping
fi

if ! command -v bc &> /dev/null; then
    echo "Устанавливаем bc..."
    sudo apt-get install -y bc
fi

# Установка snapd, если он не установлен
if ! command -v snap &> /dev/null; then
    echo "Установка snapd..."
    apt install -y snapd
    check_success
fi

# Проверка наличия Shadowsocks-Libev и его установка, если он отсутствует
if ! snap list | grep -q shadowsocks-libev; then
    echo "Установка Shadowsocks через snap..."
    snap install shadowsocks-libev
    check_success
else
    echo "Shadowsocks уже установлен."
fi

# Создание конфигурационного файла
echo "Создание конфигурационного файла..."
mkdir -p /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev
tee $CONFIG_FILE > /dev/null <<EOL
{
    "server": ["::0", "0.0.0.0"],
    "mode": "tcp_and_udp",
    "server_port": $SERVER_PORT,
    "local_port": 1080,
    "password": "$PASSWORD",
    "timeout": 60,
    "fast_open": true,
    "reuse_port": true,
    "no_delay": true,
    "method": "$METHOD"
}
EOL
check_success

# Создание и настройка службы Systemd
echo "Создание и настройка службы Systemd..."
sudo tee /etc/systemd/system/shadowsocks-libev-server@.service > /dev/null <<EOL
[Unit]
Description=Shadowsocks-Libev Custom Server Service for %I
Documentation=man:ss-server(1)
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/snap run shadowsocks-libev.ss-server -c /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/%i.json

[Install]
WantedBy=multi-user.target
EOL
check_success

# Обновите Systemd и запустите службу
echo "Обновление Systemd и запуск службы..."
sudo systemctl daemon-reload
sudo systemctl start shadowsocks-libev-server@config
check_success

# Включите службу для автозапуска
systemctl enable --now shadowsocks-libev-server@config
check_success

# Проверка статуса службы
check_service_status

# Проверка пинга и обновление /etc/hosts
check_ping_and_update_hosts

# Настройка брандмауэра (если используется ufw)
if command -v ufw &> /dev/null
then
    echo "ufw найден, проверка его статуса..."
    if ufw status | grep -q "inactive"; then
        echo "ufw активен, но не включен. Переход к настройке iptables..."
        ufw=false
    else
        echo "Настройка брандмауэра ufw..."
        ufw allow $SERVER_PORT/tcp
        check_success

        ufw allow $SERVER_PORT/udp
        check_success

        # Убедитесь, что изменения применены
        ufw reload
        check_success
    fi
else
    ufw=false
fi

# Настройка iptables (если ufw не установлен или не активен)
if [ "$ufw" = false ]; then
    echo "Настройка iptables..."
    
    if ! command -v iptables &> /dev/null; then
        echo "iptables не найден. Установка iptables..."
        apt install -y iptables
        check_success
    fi

    iptables -I INPUT -p tcp --dport $SERVER_PORT -j ACCEPT
    check_success

    iptables -I INPUT -p udp --dport $SERVER_PORT -j ACCEPT
    check_success
fi

echo "Shadowsocks успешно установлен и запущен."
echo "Конфигурация:"
echo "Server IP: $(wget -qO- ifconfig.me/ip)"
echo "Server Port: $SERVER_PORT"
echo "Password: $PASSWORD"
echo "Encryption Method: $METHOD"
