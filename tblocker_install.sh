#!/bin/bash

# Xray Torrent Blocker (tBlocker) Auto-Installer для Remnawave Node
# Версия: 1.0.2
# Автор: ProBizVPN

# Настройки отладки
DEBUG_LOG=true
SCRIPT_NAME=$(basename "$0")
LOG_FILE="${SCRIPT_NAME%.*}.log"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция логирования
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$DEBUG_LOG" = true ]; then
        echo "[$timestamp] $message" >> "$LOG_FILE"
    fi
    
    echo -e "$message"
}

# Функция для отображения заголовков
print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

# Функция для отображения успеха
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

# Функция для отображения ошибки
print_error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

# Функция для отображения предупреждения
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

# Функция для отображения информации
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    log "INFO: $1"
}

# Функция проверки прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен от имени root"
        exit 1
    fi
}

# Функция проверки наличия Remnawave Node
check_remnawave() {
    print_info "Проверяем наличие Remnawave Node..."
    
    if [ ! -d "/opt/remnanode" ]; then
        print_error "Remnawave Node не найден. Убедитесь, что он установлен."
        exit 1
    fi
    
    if [ ! -f "/opt/remnanode/docker-compose.yml" ]; then
        print_error "Файл docker-compose.yml не найден в /opt/remnanode/"
        exit 1
    fi
    
    print_success "Remnawave Node найден"
}

# Функция обработки аргументов
parse_arguments() {
    BOT_DOMAIN=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                BOT_DOMAIN="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Неизвестный параметр: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Функция отображения справки
show_help() {
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  -d, --domain DOMAIN    Домен Telegram бота для веб-хуков (например: mybotdomain.com)"
    echo "  -h, --help            Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 -d mybotdomain.com"
    echo "  $0"
}

# Функция настройки ноды
configure_node() {
    print_header "1. Настройка Remnawave Node"
    
    cd /opt/remnanode || exit 1
    
    print_info "Создаем резервную копию docker-compose.yml..."
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)
    
    print_info "Проверяем наличие старых записей tBlocker..."
    
    # Удаляем старые записи, если они есть
    if grep -q "/var/lib/toblock:/var/lib/toblock" docker-compose.yml; then
        print_warning "Найдены старые записи TBlocker, удаляем..."
        sed -i '/\/var\/lib\/toblock:\/var\/lib\/toblock/d' docker-compose.yml
        sed -i '/# Для работы Tblocker/d' docker-compose.yml
    fi
    
    # Проверяем, есть ли уже нужная запись
    if ! grep -q "/var/log/remnanode:/var/log/remnanode" docker-compose.yml; then
        print_info "Добавляем volumes для логов..."
        
        # Добавляем volumes в конец файла перед последней строкой, если её нет
        if ! grep -q "volumes:" docker-compose.yml; then
            echo "        volumes:" >> docker-compose.yml
        fi
        
        echo "            - '/var/log/remnanode:/var/log/remnanode'" >> docker-compose.yml
        print_success "Volumes для логов добавлены"
    else
        print_success "Volumes для логов уже настроены"
    fi
    
    print_info "Создаем папку для логов..."
    mkdir -p /var/log/remnanode
    chmod -R 755 /var/log/remnanode
    print_success "Папка для логов создана"
    
    print_info "Устанавливаем logrotate..."
    apt update && apt install -y logrotate
    
    print_info "Настраиваем ротацию логов..."
    cat > /etc/logrotate.d/remnanode << 'EOF'
/var/log/remnanode/*.log {
    size 50M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
EOF
    
    print_info "Запускаем ротатор логов..."
    logrotate -vf /etc/logrotate.d/remnanode
    
    print_info "Перезапускаем контейнер Remnawave Node..."
    cd /opt/remnanode
    docker compose down && docker compose up -d
    
    print_success "Настройка ноды завершена"
}

# Функция отображения инструкций по XRay
show_xray_instructions() {
    print_header "2. Настройка конфигурации XRay"
    
    echo -e "${YELLOW}============================================${NC}"
    echo -e "${YELLOW}Выполните вручную следующие шаги:${NC}"
    echo -e "${YELLOW}============================================${NC}"
    echo ""
    echo "1. Перейдите в панель Remnawave Panel"
    echo "2. Откройте профиль (конфиг XRay)"
    echo "3. Измените секцию с логами на:"
    echo ""
    echo '  "log": {'
    echo '      "error": "/var/log/remnanode/error.log",'
    echo '      "access": "/var/log/remnanode/access.log",'
    echo '      "loglevel": "error"'
    echo '  }'
    echo ""
    echo '4. В "outbounds" добавьте:'
    echo ""
    echo '  {'
    echo '    "tag": "TORRENT",'
    echo '    "protocol": "blackhole"'
    echo '  }'
    echo ""
    echo '5. В "routing" добавьте:'
    echo ""
    echo '  {'
    echo '    "type": "field",'
    echo '    "protocol": ['
    echo '      "bittorrent"'
    echo '    ],'
    echo '    "outboundTag": "TORRENT"'
    echo '  }'
    echo ""
    echo "6. Нажмите 'Форматировать и сохраните профиль'"
    echo ""
    echo -e "${YELLOW}============================================${NC}"
    
    while true; do
        read -p "Вы выполнили эти шаги? Продолжаем? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) 
                print_info "Выполните настройку XRay и запустите скрипт снова"
                exit 0
                ;;
            * ) echo "Пожалуйста, ответьте y или n.";;
        esac
    done
}

# Функция установки TBlocker
install_tblocker() {
    print_header "3. Установка tBlocker"
    
    print_info "Проверяем наличие старой версии tBlocker..."
    if command -v tblocker &> /dev/null; then
        print_warning "Найдена старая версия tBlocker, удаляем..."
        apt remove -y tblocker
        print_success "Старая версия удалена"
    fi
    
    print_info "Устанавливаем новую версию tBlocker..."
    
    # Создаем временный скрипт для автоматического ответа на вопросы установщика
    cat > /tmp/tblocker_install_answers.txt << 'EOF'
/var/log/remnanode/access.log
1
EOF
    
    print_info "Запускаем установку tBlocker..."
    bash <(curl -fsSL git.new/install) < /tmp/tblocker_install_answers.txt
    
    # Удаляем временный файл
    rm -f /tmp/tblocker_install_answers.txt
    
    print_success "tBlocker установлен"
}

# Функция запроса домена
request_domain() {
    if [ -z "$BOT_DOMAIN" ]; then
        echo ""
        while [ -z "$BOT_DOMAIN" ]; do
            read -p "Введите домен вашего бота в формате mybotdomain.com: " BOT_DOMAIN
            if [ -z "$BOT_DOMAIN" ]; then
                print_error "Домен не может быть пустым"
            fi
        done
    fi
    
    print_success "Используется домен: $BOT_DOMAIN"
}

# Функция настройки конфигурации tBlocker
configure_tblocker() {
    print_header "4. Настройка конфигурации tBlocker"
    
    request_domain
    
    print_info "Создаем резервную копию конфигурации..."
    if [ -f "/opt/tblocker/config.yaml" ]; then
        cp /opt/tblocker/config.yaml /opt/tblocker/config.yaml.backup.$(date +%Y%m%d_%H%M%S)
    fi
    
    print_info "Создаем конфигурационный файл..."
    cat > /opt/tblocker/config.yaml << EOF
LogFile: "/var/log/remnanode/access.log"
BlockDuration: 30
TorrentTag: "TORRENT"
BlockMode: "iptables"
BypassIPS:
  - "127.0.0.1"
  - "::1"
StorageDir: "/opt/tblocker"
UsernameRegex: "email: (\\\\S+)"
SendWebhook: true
WebhookURL: "https://${BOT_DOMAIN}/tblocker/webhook"
WebhookTemplate: '{"username":"%s","ip":"%s","server":"%s","action":"%s","duration":%d,"timestamp":"%s"}'
EOF
    
    print_success "Конфигурация создана"
    
    print_info "Перезапускаем tBlocker..."
    systemctl stop tblocker
    systemctl start tblocker
    
    # Проверяем статус
    if systemctl is-active --quiet tblocker; then
        print_success "tBlocker успешно запущен"
    else
        print_error "Ошибка запуска tBlocker"
        systemctl status tblocker
    fi
}

# Функция отображения финальных инструкций
show_final_instructions() {
    print_header "5. Установка модуля tBlocker для SoloBot"
    
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Установка tBlocker завершена!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Для завершения настройки выполните следующие шаги:"
    echo ""
    echo "1. Скачайте модуль из личного кабинета"
    echo "2. Внесите корректировки в файл settings"
    echo "3. Впишите хостнеймы по всех своих нод, где установлен tblocker:"
    echo ""
    echo "SERVER_COUNTRIES = {"
    echo '    "hostname1": "🇷🇺 Россия",'
    echo '    "hostname2": "🇫🇷 Франция",'
    echo '    "hostname3": "🇩🇪 Германия",'
    echo '    "hostname4": "🇺🇸 США"'
    echo "}"
    echo ""
    echo "4. Настройте уведомления, сохраните и закройте файл"
    echo "5. Загрузите папку в modules папки солобот"
    echo "6. Перезапустите бота"
    echo ""
    echo -e "${GREEN}Спасибо!${NC}"
}

# Основная функция
main() {
    print_header "Xray Torrent Blocker (tBlocker) Auto-Installer для Remnawave Node"
    
    log "Запуск скрипта с параметрами: $*"
    
    # Проверки
    check_root
    check_remnawave
    
    # Парсинг аргументов
    parse_arguments "$@"
    
    # Основные этапы установки
    configure_node
    show_xray_instructions
    install_tblocker
    configure_tblocker
    show_final_instructions
    
    echo ""
    read -p "Нажмите Enter для выхода..."
    
    log "Скрипт завершен успешно"
}

# Запуск основной функции
main "$@"