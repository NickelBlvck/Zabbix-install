#!/bin/bash

# Обновляем систему
echo "Обновляем систему..."
sudo apt-get update

# Добавляем репозиторий Zabbix
echo "Добавляем репозиторий Zabbix..."
wget https://repo.zabbix.com/zabbix/5.0/ubuntu/pool/main/z/zabbix-agent2/zabbix-agent2_5.0.21-1+ubuntu20.04_amd64.deb
sudo dpkg -i zabbix-agent2_5.0.21-1+ubuntu20.04_amd64.deb
sudo apt-get install -f

# Устанавливаем Zabbix Agent 2
echo "Устанавливаем Zabbix Agent 2..."
sudo apt-get install -y zabbix-agent2

# Путь к конфигурационному файлу Zabbix Agent 2
ZABBIX_CONF="/etc/zabbix/zabbix_agent2.conf"

# Настроим сервер и активный сервер
echo "Настраиваем Server и ServerActive..."
# Заменяем строку с Server
sudo sed -i 's/^Server=[^ ]*/Server=zabbix.kuznecoff-k.ru' $ZABBIX_CONF
# Заменяем строку с ServerActive
sudo sed -i 's/^ServerActive=[^ ]*/ServerActive=zabbix.kuznecoff-k.ru' $ZABBIX_CONF

# Добавляем параметры для Zabbix
echo "Добавляем UserParameter для fail2ban и ssh.port..."
echo "UserParameter=service.status.fail2ban,/usr/local/bin/check_fail2ban.sh" | sudo tee -a $ZABBIX_CONF > /dev/null
echo "UserParameter=ssh.port,/usr/local/bin/get_ssh_port.sh" | sudo tee -a $ZABBIX_CONF > /dev/null

# Добавляем ListenPort и Hostname
echo "Добавляем ListenPort и Hostname..."
# Добавляем строку ListenPort=10050
echo "ListenPort=10050" | sudo tee -a $ZABBIX_CONF > /dev/null

# Получаем имя хоста из системы и приводим его к правильному виду
HOSTNAME=$(hostname)
HOSTNAME_CAPITALIZED=$(echo "$HOSTNAME" | sed 's/^[a-z]/\U&/')  # Преобразуем первую букву в заглавную

# Добавляем Hostname в конфигурационный файл
echo "Hostname=$HOSTNAME_CAPITALIZED" | sudo tee -a $ZABBIX_CONF > /dev/null

# Перезагружаем Zabbix Agent 2
echo "Перезагружаем Zabbix Agent 2..."
sudo systemctl restart zabbix-agent2

# Устанавливаем скрипты для проверки fail2ban и порта SSH
echo "Загружаем скрипты из Git репозитория..."
sudo apt-get install -y git
# Скачиваем файл check_fail2ban.sh
sudo wget -O /usr/local/bin/check_fail2ban.sh https://raw.githubusercontent.com/NickelBlvck/check_fail2ban/refs/heads/main/check_fail2ban.sh
# Скачиваем файл get_ssh_port.sh
sudo wget -O /usr/local/bin/get_ssh_port.sh https://raw.githubusercontent.com/NickelBlvck/get_ssh_port/refs/heads/main/get_ssh_port.sh
# Делаем их исполнимыми
sudo chmod +x /usr/local/bin/check_fail2ban.sh
sudo chmod +x /usr/local/bin/get_ssh_port.sh

# Перезапуск сервиса Zabbix Agent 2
echo "Перезапускаем Zabbix Agent 2..."
sudo systemctl restart zabbix-agent2

# Проверка статуса
sudo systemctl status zabbix-agent2

# Выводим настроенные параметры в консоль
echo "Конфигурация Zabbix Agent 2:"
echo "ListenPort=10050"
echo "Hostname=$HOSTNAME_CAPITALIZED"

# Все готово
echo "Zabbix Agent 2 установлен и настроен."