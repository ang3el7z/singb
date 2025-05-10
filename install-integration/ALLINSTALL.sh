#!/bin/sh

# Цветовая палитра (приглушенные тона)
BG_DARK='\033[48;5;236m'
BG_ACCENT='\033[48;5;24m'
FG_MAIN='\033[38;5;252m'
FG_ACCENT='\033[38;5;85m'
FG_WARNING='\033[38;5;214m'
FG_SUCCESS='\033[38;5;41m'
FG_ERROR='\033[38;5;203m'
RESET='\033[0m'

# Символы оформления
SEP_CHAR="◈"
ARROW="▸"
CHECK="✓"
CROSS="✗"
INDENT="  "

# Функция разделителя
separator() {
    echo -e "${WHITE}                -------------------------------------                ${RESET}"
}

header() {
    clear
    separator
    echo -e "${BG_ACCENT}${FG_MAIN}                Установка и настройка sing-box                ${RESET}"
    separator
}

show_progress() {
    echo -e "${INDENT}${ARROW} ${FG_ACCENT}$1${RESET}"
}

show_success() {
    echo -e "${INDENT}${CHECK} ${FG_SUCCESS}$1${RESET}\n"
}

show_error() {
    echo -e "${INDENT}${CROSS} ${FG_ERROR}$1${RESET}\n"
}

show_warning() {
    echo -e "${INDENT}! ${FG_WARNING}$1${RESET}\n"
}

header

# Обновление репозиториев и установка зависимостей
show_progress "Обновление пакетов и установка зависимостей..."
opkg update && opkg install openssh-sftp-server nano curl jq
[ $? -eq 0 ] && show_success "Зависимости успешно установлены" || show_error "Ошибка установки зависимостей"
separator

sleep 1
read -p "$(echo -e "  ${FG_ACCENT}▷ URL подписки на конфигурацию (Enter для ручного ввода): ${RESET}")" CONFIG_URL

# Установка sing-box
show_progress "Установка последней версии sing-box..."
opkg install sing-box
if [ $? -eq 0 ]; then
    show_success "Sing-box успешно установлен"
else
    show_error "Ошибка установки sing-box"
    exit 1
fi

# Конфигурация сервиса
show_progress "Настройка системного сервиса..."
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
show_success "Конфигурация сервиса применена"

# Отключение сервиса
service sing-box disable
show_warning "Сервис временно отключен"

# Очистка конфигурации
echo '{}' > /etc/sing-box/config.json
show_warning "Конфигурационный файл сброшен"

separator

# Создание сетевого интерфейса
configure_proxy() {
    show_progress "Создание сетевого интерфейса proxy..."
    uci set network.proxy=interface
    uci set network.proxy.proto="none"
    uci set network.proxy.device="singtun0"
    uci set network.proxy.defaultroute="0"
    uci set network.proxy.delegate="0"
    uci set network.proxy.peerdns="0"
    uci set network.proxy.auto="1"
    uci commit network
    if service network restart; then
        show_success "Сетевой интерфейс настроен"
    else
        show_error "Ошибка настройки сети"
    fi
}
configure_proxy

# Настройка фаервола
configure_firewall() {
    show_progress "Конфигурация правил фаервола..."
    
    # Добавляем зону только если её не существует
    if ! uci -q get firewall.proxy >/dev/null; then
        uci add firewall zone >/dev/null
        uci set firewall.@zone[-1].name="proxy"
        uci set firewall.@zone[-1].forward="REJECT"
        uci set firewall.@zone[-1].output="ACCEPT"
        uci set firewall.@zone[-1].input="ACCEPT"
        uci set firewall.@zone[-1].masq="1"
        uci set firewall.@zone[-1].mtu_fix="1"
        uci set firewall.@zone[-1].device="singtun0"
        uci set firewall.@zone[-1].family="ipv4"
        uci add_list firewall.@zone[-1].network="singtun0"
    fi

    # Добавляем forwarding только если не существует
    if ! uci -q get firewall.@forwarding[-1].dest="proxy" >/dev/null; then
        uci add firewall forwarding >/dev/null
        uci set firewall.@forwarding[-1].dest="proxy"
        uci set firewall.@forwarding[-1].src="lan"
        uci set firewall.@forwarding[-1].family="ipv4"
    fi

    uci commit firewall >/dev/null 2>&1
    service firewall reload >/dev/null 2>&1
    
    show_success "Правила фаервола применены"
}
configure_firewall

# Автоматическая настройка конфигурации
separator
AUTO_CONFIG_SUCCESS=0
show_progress "Импорт конфигурации sing-box"

# Проверяем, что URL не пустой
if [ -n "$CONFIG_URL" ]; then
    MAX_ATTEMPTS=3  # Максимальное количество попыток загрузки
    ATTEMPT=1  # Счетчик попыток
    SUCCESS=0  # Флаг успешной загрузки

    # Пытаемся загрузить конфигурацию
    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        show_progress "Загрузка конфигурации с ${CONFIG_URL} (Попытка $ATTEMPT из $MAX_ATTEMPTS)"
        RAW_JSON=$(curl -fsS "$CONFIG_URL" 2>&1)
        
        if [ $? -eq 0 ]; then
            FORMATTED_JSON=$(echo "$RAW_JSON" | jq '.' 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                echo "$FORMATTED_JSON" > /etc/sing-box/config.json
                show_success "Конфигурация успешно загружена"
                echo "$CONFIG_URL" > "/etc/sing-box/url_config.json"
                
                show_progress "Активация сервиса"
                service sing-box enable
                service sing-box restart
                show_success "Сервис успешно запущен"
                AUTO_CONFIG_SUCCESS=1
                SUCCESS=1
                break  # Выход из цикла, если загрузка успешна
            else
                show_error "Ошибка формата конфигурации"
            fi
        else
            show_error "Ошибка загрузки: ${RAW_JSON}"
        fi

        # Если загрузка не удалась, увеличиваем счетчик попыток
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            show_warning "Попробую снова..."
        fi
        
        ATTEMPT=$((ATTEMPT + 1))  # Увеличиваем счетчик попыток
    done

    # Если все попытки не удались, переходим к ручной настройке
    if [ $SUCCESS -eq 0 ]; then
        show_warning "Переход к ручной настройке конфигурации"
        nano /etc/sing-box/config.json
    fi
else
    show_warning "Ручная настройка конфигурации"
    nano /etc/sing-box/config.json
fi

# Проверка ручной конфигурации
if [ "$AUTO_CONFIG_SUCCESS" -eq 0 ]; then
    while true; do
        separator
        read -p "$(echo -e "  ${FG_ACCENT}▷ Завершили редактирование config.json? [y/N]: ${RESET}")" yn
        case ${yn:-n} in
            [Yy]* )
                service sing-box enable
                service sing-box restart
                show_success "Сервис активирован"
                break
                ;;
            [Nn]* )
                nano /etc/sing-box/config.json
                ;;
            * )
                show_error "Некорректный ввод"
                ;;
        esac
    done
fi

# Создание резервных конфигов
show_progress "Создание файлов резервных конфигураций..."
for i in 2 3; do
    if [ ! -f "/etc/sing-box/config${i}.json" ]; then
        echo '{}' > "/etc/sing-box/config${i}.json"
    fi
done
show_success "Резервные файлы созданы"

show_progress "Создание url файлов..."
touch /etc/sing-box/url_config.json
touch /etc/sing-box/url_config2.json
touch /etc/sing-box/url_config3.json
show_success "Обновления созданы"

show_progress "Создание singb-updater..."
wget -O /usr/bin/singb-updater https://raw.githubusercontent.com/Vancltkin/singb/main/folder/user/bin/singb-updater
show_success "Обновления созданы"

show_progress "Настройка доступов..."
chmod 755 /usr/bin/singb-updater
chown root:root /usr/bin/singb-updater
chmod 644 /etc/sing-box/*
show_success "Доступы получены"

# Установка веб-интерфейса
separator
show_progress "Установка веб-интерфейса singb..."
wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk
chmod 0755 /root/luci-app-singb.ipk
opkg update
opkg install /root/luci-app-singb.ipk
/etc/init.d/uhttpd restart
show_success "Веб-интерфейс установлен"

# Очистка системы
separator
show_progress "Оптимизация системы..."
find /tmp -name "luci-*cache*" -exec rm -f {} \; 2>/dev/null
rm -f /var/lib/uhttpd* 2>/dev/null
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart
killall -HUP dnsmasq 2>/dev/null
chmod 755 /www/luci-static/singb 2>/dev/null
show_success "Система оптимизирована"

# Отключение IPv6
separator
show_progress "Отключение IPv6..."
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
/etc/init.d/odhcpd disable
uci commit
show_success "IPv6 отключен"

show_progress "Перезапуск сервисов..."
/etc/init.d/network restart && service sing-box restart
show_success "Сервисы перезапущены"

separator
echo -e "${BG_ACCENT}${FG_MAIN} Установка завершена! Доступ к панели: http://192.168.1.1 ${RESET}"
separator
