#!/bin/bash

# Логирование
LOG_FILE="/var/log/zabbix_agent_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Переменные
GITHUB_REPO="https://raw.githubusercontent.com/NickelBlvck"
CHECK_FAIL2BAN_URL="$GITHUB_REPO/check_fail2ban/refs/heads/main/check_fail2ban.sh"
GET_SSH_PORT_URL="$GITHUB_REPO/get_ssh_port/refs/heads/main/get_ssh_port.sh"
ZABBIX_CONF="/etc/zabbix/zabbix_agentd.conf"

# Устанавливаем Zabbix Agent
echo "Устанавливаем Zabbix Agent..."
sudo apt-get update || { echo "Ошибка при обновлении пакетов"; exit 1; }
sudo apt-get install -y zabbix-agent || { echo "Ошибка при установке Zabbix Agent"; exit 1; }

# Проверка наличия конфигурационного файла
if [ ! -f "$ZABBIX_CONF" ]; then
    echo "Конфигурационный файл Zabbix Agent не найден: $ZABBIX_CONF"
    exit 1
fi

# Настроим сервер и активный сервер
echo "Настраиваем Server и ServerActive..."
sudo sed -i 's/^Server=[^ ]*/Server=zabbix.kuznecoff-k.ru/' $ZABBIX_CONF
sudo sed -i 's/^ServerActive=[^ ]*/ServerActive=zabbix.kuznecoff-k.ru/' $ZABBIX_CONF

# Добавляем ListenPort
echo "Добавляем ListenPort..."
echo "ListenPort=10050" | sudo tee -a $ZABBIX_CONF > /dev/null

# Получаем имя хоста из системы и приводим его к правильному виду
HOSTNAME=$(hostname)
HOSTNAME_CAPITALIZED=$(echo "$HOSTNAME" | sed 's/^[a-z]/\U&/')  # Преобразуем первую букву в заглавную

# Добавляем Hostname в конфигурационный файл
echo "Hostname=$HOSTNAME_CAPITALIZED" | sudo tee -a $ZABBIX_CONF > /dev/null

# Добавляем параметры для Zabbix
echo "Добавляем UserParameter для fail2ban и ssh.port..."
echo "UserParameter=service.status.fail2ban,/usr/local/bin/check_fail2ban.sh" | sudo tee -a $ZABBIX_CONF > /dev/null
echo "UserParameter=ssh.port,/usr/local/bin/get_ssh_port.sh" | sudo tee -a $ZABBIX_CONF > /dev/null

# Перезагружаем Zabbix Agent
echo "Перезагружаем Zabbix Agent..."
sudo systemctl restart zabbix-agent || { echo "Ошибка при перезапуске Zabbix Agent"; exit 1; }

# Устанавливаем скрипты для проверки fail2ban и порта SSH
echo "Загружаем скрипты из Git репозитория..."
sudo apt-get install -y git || { echo "Ошибка при установке git"; exit 1; }

# Скачиваем файл check_fail2ban.sh
sudo wget -O /usr/local/bin/check_fail2ban.sh $CHECK_FAIL2BAN_URL || { echo "Ошибка при загрузке check_fail2ban.sh"; exit 1; }

# Скачиваем файл get_ssh_port.sh
sudo wget -O /usr/local/bin/get_ssh_port.sh $GET_SSH_PORT_URL || { echo "Ошибка при загрузке get_ssh_port.sh"; exit 1; }

# Делаем их исполнимыми
sudo chmod +x /usr/local/bin/check_fail2ban.sh
sudo chmod +x /usr/local/bin/get_ssh_port.sh

# Перезапуск сервиса Zabbix Agent
echo "Перезапускаем Zabbix Agent..."
sudo systemctl restart zabbix-agent || { echo "Ошибка при перезапуске Zabbix Agent"; exit 1; }

# Проверка статуса
if ! sudo systemctl is-active --quiet zabbix-agent; then
    echo "Zabbix Agent не запущен"
    exit 1
fi

# Запрос наименования узла у пользователя
echo "Введите наименование узла (Hostname), которое будет использоваться в Zabbix:"
read -r USER_HOSTNAME

# Проверка, что пользователь ввел значение
if [ -z "$USER_HOSTNAME" ]; then
    echo "Наименование узла не может быть пустым. Используется значение по умолчанию: $HOSTNAME_CAPITALIZED"
    USER_HOSTNAME="$HOSTNAME_CAPITALIZED"
fi

# Обновляем Hostname в конфигурационном файле
sudo sed -i "s/^Hostname=.*/Hostname=$USER_HOSTNAME/" $ZABBIX_CONF

# Перезапускаем Zabbix Agent с новым Hostname
echo "Перезапускаем Zabbix Agent с новым Hostname..."
sudo systemctl restart zabbix-agent || { echo "Ошибка при перезапуске Zabbix Agent"; exit 1; }

# Выводим настроенные параметры в консоль
echo "Конфигурация Zabbix Agent:"
echo "ListenPort=10050"
echo "Hostname=$USER_HOSTNAME"

# Все готово
echo "Zabbix Agent установлен и настроен."