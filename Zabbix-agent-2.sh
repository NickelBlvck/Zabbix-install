#!/bin/bash

# Логирование
LOG_FILE="/var/log/zabbix_agent2_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Переменные
ZABBIX_RELEASE_DEB="zabbix-release_latest_7.4+ubuntu22.04_all.deb"
ZABBIX_RELEASE_URL="https://repo.zabbix.com/zabbix/7.4/release/ubuntu/pool/main/z/zabbix-release/ $ZABBIX_RELEASE_DEB"

GITHUB_REPO="https://github.com/NickelBlvck "
SCRIPT_DIR="/etc/zabbix/scripts"
ZABBIX_CONF="/etc/zabbix/zabbix_agent2.conf"
ZABBIX_SERVICE="zabbix-agent2"

# Функция вывода ошибок
log_error() {
    echo "❌ Ошибка: $1" >&2
    exit 1
}

# Обновление системы
echo "🔄 Обновляем систему..."
sudo apt update && sudo apt upgrade -y || log_error "Не удалось обновить систему."

# Установка зависимостей
echo "📦 Устанавливаем зависимости: wget, git, curl..."
sudo apt install -y wget git curl || log_error "Не удалось установить зависимости."

# Проверяем, установлен ли zabbix-agent2
if systemctl list-units | grep -q "$ZABBIX_SERVICE"; then
    echo "ℹ️ Zabbix Agent 2 уже установлен."
else
    echo "🌐 Загружаем и устанавливаем репозиторий Zabbix 7.4..."
    sudo wget -O "/tmp/$ZABBIX_RELEASE_DEB" "$ZABBIX_RELEASE_URL" --show-progress || log_error "Не удалось загрузить zabbix-release.deb"
    sudo dpkg -i "/tmp/$ZABBIX_RELEASE_DEB" || log_error "Не удалось установить zabbix-release.deb"
    sudo apt update || log_error "Не удалось обновить пакеты после добавления репозитория."

    echo "📥 Устанавливаем Zabbix Agent 2..."
    sudo apt install -y zabbix-agent2 || log_error "Не удалось установить zabbix-agent2"
fi

# Проверяем наличие конфигурационного файла
if [ ! -f "$ZABBIX_CONF" ]; then
    log_error "Конфигурационный файл не найден: $ZABBIX_CONF"
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

# Создаём директорию для скриптов
sudo mkdir -p "$SCRIPT_DIR"

# Удаляем старые версии скриптов, если они есть
sudo rm -f "$SCRIPT_DIR"/*.sh

# Клонируем репозитории
cd /tmp || exit 1

echo "📂 Клонируем репозитории..."
if [ -d "check_fail2ban" ]; then sudo rm -rf check_fail2ban; fi
git clone "$GITHUB_REPO/check_fail2ban.git" || log_error "Ошибка при клонировании check_fail2ban"
sudo cp check_fail2ban/check_fail2ban.sh "$SCRIPT_DIR/"

if [ -d "get_ssh_port" ]; then sudo rm -rf get_ssh_port; fi
git clone "$GITHUB_REPO/get_ssh_port.git" || log_error "Ошибка при клонировании get_ssh_port"
sudo cp get_ssh_port/get_ssh_port.sh "$SCRIPT_DIR/"

# Делаем скрипты исполняемыми
sudo chmod +x "$SCRIPT_DIR"/*.sh

# Удаляем старые UserParameter'ы
sudo sed -i '/UserParameter=service.status.fail2ban/d' "$ZABBIX_CONF"
sudo sed -i '/UserParameter=ssh.port/d' "$ZABBIX_CONF"

# Добавляем новые UserParameter'ы
echo "UserParameter=service.status.fail2ban,$SCRIPT_DIR/check_fail2ban.sh" | sudo tee -a "$ZABBIX_CONF" > /dev/null
echo "UserParameter=ssh.port,$SCRIPT_DIR/get_ssh_port.sh" | sudo tee -a "$ZABBIX_CONF" > /dev/null

# Перезапуск службы
echo "🔁 Перезапускаем Zabbix Agent 2..."
sudo systemctl enable --now "$ZABBIX_SERVICE" || log_error "Не удалось запустить службу."
sudo systemctl restart "$ZABBIX_SERVICE" || log_error "Не удалось перезапустить службу."

# Проверка статуса
if ! sudo systemctl is-active --quiet "$ZABBIX_SERVICE"; then
    log_error "Служба $ZABBIX_SERVICE не запущена!"
fi

# Ввод имени хоста от пользователя
read -rp "Введите наименование узла (Hostname) для Zabbix (Enter — использовать '$HOSTNAME_CAPITALIZED'): " USER_HOSTNAME
USER_HOSTNAME=${USER_HOSTNAME:-$HOSTNAME_CAPITALIZED}

# Обновление Hostname в конфиге
sudo sed -i "s/^Hostname=.*/Hostname=$USER_HOSTNAME/" "$ZABBIX_CONF"

# Перезапуск после изменения Hostname
sudo systemctl restart "$ZABBIX_SERVICE" || log_error "Не удалось перезапустить Zabbix Agent 2."

# Вывод информации
echo -e "\n✅ Zabbix Agent 2 успешно установлен и настроен."
echo "📂 Скрипты размещены в: $SCRIPT_DIR"
echo "🔌 Port: 10050"
echo "🖥️ Hostname: $USER_HOSTNAME"