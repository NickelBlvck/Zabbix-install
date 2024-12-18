#!/bin/bash

# Устанавливаем Zabbix Agent
echo "Устанавливаем Zabbix Agent..."
sudo apt-get update
sudo apt-get install -y zabbix-agent

# Путь к конфигурационному файлу Zabbix Agent
ZABBIX_CONF="/etc/zabbix/zabbix_agentd.conf"

# Настроим сервер и активный сервер
echo "Настраиваем Server и ServerActive..."
sudo sed -i 's/^#Server=127.0.0.1/Server=zabbix.kuznecoff.tech/' $ZABBIX_CONF
sudo sed -i 's/^#ServerActive=127.0.0.1/ServerActive=zabbix.kuznecoff.tech/' $ZABBIX_CONF

# Добавляем параметры для Zabbix
echo "Добавляем UserParameter для fail2ban и ssh.port..."
echo "UserParameter=service.status.fail2ban,/usr/local/bin/check_fail2ban.sh" | sudo tee -a $ZABBIX_CONF > /dev/null
echo "UserParameter=ssh.port,/usr/local/bin/get_ssh_port.sh" | sudo tee -a $ZABBIX_CONF > /dev/null

# Перезагружаем Zabbix Agent
echo "Перезагружаем Zabbix Agent..."
sudo systemctl restart zabbix-agent

# Устанавливаем скрипты для проверки fail2ban и порта SSH
echo "Загружаем скрипты из Git репозитория..."
sudo apt-get install -y git
sudo git clone https://github.com/NickelBlvck/check_fail2ban /usr/local/bin/check_fail2ban.sh
sudo git clone https://github.com/NickelBlvck/get_ssh_port /usr/local/bin/get_ssh_port.sh

# Делаем скрипты исполнимыми
echo "Делаем скрипты исполнимыми..."
sudo chmod +x /usr/local/bin/check_fail2ban.sh
sudo chmod +x /usr/local/bin/get_ssh_port.sh

# Все готово
echo "Zabbix Agent установлен и настроен."