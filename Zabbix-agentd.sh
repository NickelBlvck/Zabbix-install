#!/bin/bash

# Устанавливаем Zabbix Agent
echo "Устанавливаем Zabbix Agent..."
sudo apt-get update
sudo apt-get install -y zabbix-agent

# Путь к конфигурационному файлу Zabbix Agent
ZABBIX_CONF="/etc/zabbix/zabbix_agentd.conf"

# Настроим сервер и активный сервер
echo "Настраиваем Server и ServerActive..."
# Заменяем строку с Server
sudo sed -i 's/^Server=[^ ]*/Server=zabbix.kuznecoff.tech/' $ZABBIX_CONF
# Заменяем строку с ServerActive
sudo sed -i 's/^ServerActive=[^ ]*/ServerActive=zabbix.kuznecoff.tech/' $ZABBIX_CONF


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
# Скачиваем файл check_fail2ban.sh
sudo wget -O /usr/local/bin/check_fail2ban.sh https://raw.githubusercontent.com/NickelBlvck/check_fail2ban/refs/heads/main/check_fail2ban.sh
# Скачиваем файл get_ssh_port.sh
sudo wget -O /usr/local/bin/get_ssh_port.sh https://raw.githubusercontent.com/NickelBlvck/get_ssh_port/refs/heads/main/get_ssh_port.sh
# Делаем их исполнимыми
sudo chmod +x /usr/local/bin/check_fail2ban.sh
sudo chmod +x /usr/local/bin/get_ssh_port.sh
# Перезапуск сервиса Zabbix Agent
sudo systemctl restart zabbix-agent
# Проверка статуса
sudo systemctl status zabbix-agent
# Все готово
echo "Zabbix Agent установлен и настроен."
