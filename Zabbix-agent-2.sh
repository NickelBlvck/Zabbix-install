#!/bin/bash

# Логирование
LOG_FILE="/var/log/zabbix_agent2_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Переменные
UBUNTU_VERSION=$(lsb_release -cs)  # jammy
ZABBIX_RELEASE_DEB="zabbix-release_latest_7.4+ubuntu22.04_all.deb"
ZABBIX_RELEASE_URL="https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/ $ZABBIX_RELEASE_DEB"

ZABBIX_CONF="/etc/zabbix/zabbix_agent2.conf"
ZABBIX_SERVICE="zabbix-agent2"

# GitHub URL для скриптов
GITHUB_REPO="https://raw.githubusercontent.com/NickelBlvck "
CHECK_FAIL2BAN_URL="$GITHUB_REPO/check_fail2ban/main/check_fail2ban.sh"
GET_SSH_PORT_URL="$GITHUB_REPO/get_ssh_port/main/get_ssh_port.sh"

# Функция вывода ошибок
log_error() {
    echo "❌ Ошибка: $1" >&2
    exit 1
}

# Обновление системы
echo "🔄 Обновляем систему..."
sudo apt update && sudo apt upgrade -y || log_error "Не удалось обновить систему."

# Установка зависимостей
echo "📦 Устанавливаем необходимые зависимости..."
sudo apt install -y wget curl git || log_error "Не удалось установить зависимости."

# Проверка наличия Zabbix Agent 2
if systemctl list-units | grep -q "$ZABBIX_SERVICE"; then
    echo "ℹ️ Zabbix Agent 2 уже установлен."
else
    echo "🌐 Загружаем и добавляем репозиторий Zabbix 7.4..."
    sudo wget -O "/tmp/$ZABBIX_RELEASE_DEB" "$ZABBIX_RELEASE_URL" || log_error "Не удалось загрузить zabbix-release."
    sudo dpkg -i "/tmp/$ZABBIX_RELEASE_DEB" || log_error "Не удалось установить zabbix-release."
    sudo apt update || log_error "Ошибка при обновлении пакетов после добавления репозитория."

    echo "📥 Устанавливаем Zabbix Agent 2..."
    sudo apt install -y zabbix-agent2 || log_error "Не удалось установить Zabbix Agent 2."
fi

# Проверка конфигурационного файла
if [ ! -f "$ZABBIX_CONF" ]; then
    log_error "Конфигурационный файл не найден: $ZABBIX_CONF"
fi

# Получение имени хоста
HOSTNAME_CAPITALIZED=$(hostname | sed 's/^[a-z]/\U&/')

# Настройка конфигурации
echo "⚙️ Настраиваем конфигурацию Zabbix Agent 2..."
sudo tee "$ZABBIX_CONF" > /dev/null <<EOF
PidFile=/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=zabbix.kuznecoff-k.ru
ServerActive=zabbix.kuznecoff-k.ru
Hostname=$HOSTNAME_CAPITALIZED
ListenPort=10050
Include=/etc/zabbix/zabbix_agent2.d/*.conf
UserParameter=service.status.fail2ban,/usr/local/bin/check_fail2ban.sh
UserParameter=ssh.port,/usr/local/bin/get_ssh_port.sh
EOF

# Создание директории для скриптов, если её нет
sudo mkdir -p /usr/local/bin/

# Скачивание скриптов
echo "📂 Загружаем пользовательские скрипты..."
sudo wget -O /usr/local/bin/check_fail2ban.sh "$CHECK_FAIL2BAN_URL" || log_error "Ошибка загрузки check_fail2ban.sh"
sudo wget -O /usr/local/bin/get_ssh_port.sh "$GET_SSH_PORT_URL" || log_error "Ошибка загрузки get_ssh_port.sh"

sudo chmod +x /usr/local/bin/check_fail2ban.sh /usr/local/bin/get_ssh_port.sh

# Перезапуск службы
echo "🔁 Перезапускаем Zabbix Agent 2..."
sudo systemctl enable --now "$ZABBIX_SERVICE" || log_error "Не удалось запустить службу."
sudo systemctl restart "$ZABBIX_SERVICE" || log_error "Не удалось перезапустить службу."

# Проверка статуса
if ! sudo systemctl is-active --quiet "$ZABBIX_SERVICE"; then
    log_error "Служба $ZABBIX_SERVICE не запущена!"
fi

# Ввод имени хоста от пользователя
read -rp "Введите наименование узла (Hostname), которое будет использоваться в Zabbix (Enter для использования '$HOSTNAME_CAPITALIZED'): " USER_HOSTNAME
USER_HOSTNAME=${USER_HOSTNAME:-$HOSTNAME_CAPITALIZED}

# Обновление Hostname в конфиге
sudo sed -i "s/^Hostname=.*/Hostname=$USER_HOSTNAME/" "$ZABBIX_CONF"

# Перезапуск после изменения Hostname
sudo systemctl restart "$ZABBIX_SERVICE" || log_error "Не удалось перезапустить Zabbix Agent 2."

# Вывод информации
echo -e "\n✅ Zabbix Agent 2 успешно установлен и настроен."
echo "🔌 ListenPort: 10050"
echo "🖥️ Hostname: $USER_HOSTNAME"