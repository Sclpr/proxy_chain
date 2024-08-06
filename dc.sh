#!/bin/bash

# Функция для проверки, что строка состоит только из цифр
is_digits() {
    [[ $1 =~ ^[0-9]+$ ]]
}

# Функция для проверки, что строка является корректным IP-адресом
is_valid_ip() {
    local ip="$1"
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && \
    [[ "$ip" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.\
(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.\
(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.\
(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]
}

# Спрашиваем пользователя о значениях переменных
while true; do
    read -p "Введите пароль (по умолчанию 123456, только цифры): " PASSWORD
    PASSWORD=${PASSWORD:-123456}

    if is_digits "$PASSWORD"; then
        break
    else
        echo "Ошибка: пароль должен состоять только из цифр."
    fi
done

read -p "Введите внутренний порт (по умолчанию 8388): " PORT_IN
PORT_IN=${PORT_IN:-8388}

while true; do
    read -p "Введите внешний IP: " IP
    if is_valid_ip "$IP"; then
        break
    else
        echo "Ошибка: введенный IP-адрес некорректен. Попробуйте снова."
    fi
done

read -p "Введите внешний порт (по умолчанию 8388): " PORT_OUT
PORT_OUT=${PORT_OUT:-8388}

# Обновляем списки пакетов
sudo apt-get update

# Устанавливаем необходимые зависимости
sudo apt-get install -y \
    ca-certificates \
    wget \
    gnupg \
    lsb-release \
    nano

# Создаем директорию для ключей
sudo mkdir -p /etc/apt/keyrings

# Создаем временный файл для ключа
TMP_KEYRING="/tmp/docker.gpg"

# Загружаем и добавляем ключ GPG для Docker
wget -O- https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o "$TMP_KEYRING"

# Перемещаем временный файл в нужное место
sudo mv "$TMP_KEYRING" /etc/apt/keyrings/docker.gpg

# Добавляем репозиторий Docker в источники apt
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновляем списки пакетов
sudo apt-get update

# Устанавливаем Docker и связанные с ним пакеты
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Загружаем Docker Compose
sudo wget -O /usr/local/bin/docker-compose "https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-$(uname -s)-$(uname -m)"

# Даем права на выполнение
sudo chmod +x /usr/local/bin/docker-compose

# Проверяем установку Docker
docker --version

# Проверяем установку Docker Compose
docker-compose --version

# Создаем docker-compose.yml файл
sudo tee docker-compose.yml > /dev/null <<EOF
version: '3.0'
services:
  api:
    image: nadoo/glider
    container_name: proxy
    ports:
      - "1080:1080"
      - "${PORT_IN}:${PORT_IN}"
    restart: unless-stopped
    logging:
      driver: 'json-file'
      options:
        max-size: '800k'
        max-file: '10'
    command: -verbose -listen ss://AEAD_AES_256_GCM:${PASSWORD}@api:${PORT_IN} -forward ss://AEAD_AES_256_GCM:${PASSWORD}@${IP}:${PORT_OUT}
EOF

# Запускаем docker-compose
sudo docker-compose up -d

# Проверяем наличие ufw и статус
if sudo ufw status | grep -q "Status: active"; then
  echo "ufw активен. Добавляем правила для портов..."
  sudo ufw allow ${PORT_IN}/tcp
  sudo ufw allow ${PORT_IN}/udp
  sudo ufw allow ${PORT_OUT}/tcp
  sudo ufw allow ${PORT_OUT}/udp
  sudo ufw allow 1080/tcp
  sudo ufw allow 1080/udp
  sudo ufw reload
else
  echo "ufw не активен или не установлен. Пропускаем настройку ufw."
fi

echo "Установка прокси завершена"
echo "Конфигурация:"
echo "Server IP: $(curl -s ifconfig.me)"
echo "Server Port: $PORT_IN"
echo "Password: $PASSWORD"
echo "Encryption Method: AEAD_AES_256_GCM"
