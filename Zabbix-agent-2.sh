#!/bin/bash

# Логирование
LOG_FILE="/var/log/zabbix_agent2_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Переменные
GITHUB_REPO="https://raw.githubusercontent.com/NickelBlvck "
CHECK_FAIL2BAN_URL="$GITHUB_REPO/check_fail2ban/main/check_fail2ban.sh"
GET_SSH_PORT_URL="$GITHUB_REPO/get_ssh_port/main/get_ssh_port.sh"
ZABBIX_CONF="/etc/zabbix/zabbix_agent2.conf"

ZABBIX_RELEASE_DEB="zabbix-release_latest_7.4+ubuntu22.04_all.deb"
ZABBIX_RELEASE_URL="https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/ $ZABBIX_RELEASE_DEB"

# Обновляем систему
echo "🔄 Обновляем систему..."
sudo apt update && sudo apt upgrade -y || { echo "❌ Ошибка: не удалось обновить пакеты"; exit 1; }

# Устанавливаем зависимости
echo "📦 Устанавливаем зависимости: wget, git, curl..."
sudo apt install -y wget git curl || { echo "❌ Ошибка: не удалось установить зависимости"; exit 1; }

# Проверяем, установлен ли zabbix-agent2
if systemctl list-units | grep -q "zabbix-agent2"; then
    echo "ℹ️ Zabbix Agent 2 уже установлен."
else
    # Скачиваем и устанавливаем zabbix-release
    echo "🌐 Загружаем репозиторий Zabbix 7.4..."
    sudo wget -O "/tmp/$ZABBIX_RELEASE_DEB" "$ZABBIX_RELEASE_URL" --show-progress || {
        echo "❌ Ошибка: не удалось загрузить zabbix-release.deb"
        cat wget-log 2>/dev/null
        exit 1
    }
    sudo dpkg -i "/tmp/$ZABBIX_RELEASE_DEB" || { echo "❌ Ошибка: не удалось установить zabbix-release"; exit 1; }

    echo "🔁 Обновляем список пакетов..."
    sudo apt update || { echo "❌ Ошибка: не удалось обновить пакеты после добавления репозитория"; exit 1; }

    echo "📥 Устанавливаем Zabbix Agent 2..."
    sudo apt install -y zabbix-agent2 || { echo "❌ Ошибка: не удалось установить zabbix-agent2"; exit 1; }
fi

# Проверяем наличие конфига
if [ ! -f "$ZABBIX_CONF" ]; then
    echo "❌ Конфигурационный файл $ZABBIX_CONF не найден!"
    exit 1
fi

# Настройка Server и ServerActive
echo "⚙️ Настраиваем Server и ServerActive..."
sudo sed -i 's/^Server=.*/Server=zabbix.kuznecoff-k.ru/' "$ZABBIX_CONF"
sudo sed -i 's/^ServerActive=.*/ServerActive=zabbix.kuznecoff-k.ru/' "$ZABBIX_CONF"

# Добавляем ListenPort
echo "ListenPort=10050" | sudo tee -a "$ZABBIX_CONF" > /dev/null

# Получаем имя хоста с первой заглавной буквы
HOSTNAME_CAPITALIZED=$(hostname | sed 's/^[a-z]/\U&/')

# Устанавливаем Hostname
echo "Hostname=$HOSTNAME_CAPITALIZED" | sudo tee -a "$ZABBIX_CONF" > /dev/null

# Добавляем UserParameter'ы
echo "🛠️ Добавляем пользовательские параметры..."
echo "UserParameter=service.status.fail2ban,/usr/local/bin/check_fail2ban.sh" | sudo tee -a "$ZABBIX_CONF" > /dev/null
echo "UserParameter=ssh.port,/usr/local/bin/get_ssh_port.sh" | sudo tee -a "$ZABBIX_CONF" > /dev/null

# Перезапускаем службу
echo "🔁 Перезапускаем Zabbix Agent 2..."
sudo systemctl restart zabbix-agent2 || { echo "❌ Ошибка: не удалось перезапустить zabbix-agent2"; exit 1; }

# Проверяем статус службы
if ! sudo systemctl is-active --quiet zabbix-agent2; then
    echo "❌ Ошибка: zabbix-agent2 не запущен"
    exit 1
fi

# Скачиваем скрипты из GitHub
echo "📂 Загружаем скрипты из GitHub..."
sudo mkdir -p /usr/local/bin/

sudo wget -O /usr/local/bin/check_fail2ban.sh "$CHECK_FAIL2BAN_URL" || { echo "❌ Ошибка: не удалось загрузить check_fail2ban.sh"; exit 1; }
sudo wget -O /usr/local/bin/get_ssh_port.sh "$GET_SSH_PORT_URL" || { echo "❌ Ошибка: не удалось загрузить get_ssh_port.sh"; exit 1; }

sudo chmod +x /usr/local/bin/check_fail2ban.sh /usr/local/bin/get_ssh_port.sh

# Перезапуск после установки скриптов
sudo systemctl restart zabbix-agent2

# Ввод имени хоста
read -rp "Введите наименование узла (Hostname) для Zabbix (Enter — использовать '$HOSTNAME_CAPITALIZED'): " USER_HOSTNAME
USER_HOSTNAME=${USER_HOSTNAME:-$HOSTNAME_CAPITALIZED}

# Обновляем Hostname в конфиге
sudo sed -i "s/^Hostname=.*/Hostname=$USER_HOSTNAME/" "$ZABBIX_CONF"

# Перезапуск с новым Hostname
sudo systemctl restart zabbix-agent2 || { echo "❌ Ошибка: не удалось перезапустить zabbix-agent2"; exit 1; }

# Вывод информации
echo -e "\n✅ Zabbix Agent 2 успешно установлен и настроен."
echo "🔌 Port: 10050"
echo "🖥️ Hostname: $USER_HOSTNAME"