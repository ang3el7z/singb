#!/bin/sh

# Цветовые коды
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BGBLUE='\033[44m'
NC='\033[0m' # No Color

# Функция для отрисовки разделителя
separator() {
    echo -e "${BGBLUE}${WHITE}=======================================================${NC}\n"
}

clear
separator
echo -e "${BGBLUE}${WHITE} Начало установки sing-box ${NC}"
separator

# Обновление репозиториев и установка зависимостей
echo -e "${CYAN}► Обновляю репозитории и устанавливаю зависимости...${NC}"
opkg update && opkg install openssh-sftp-server nano curl jq
echo -e "${GREEN}✓ Зависимости успешно установлены${NC}\n"

# Функция для установки конкретной версии
install_version() {
    case $1 in
        1)
            echo -e "${YELLOW}▶ Скачиваю и устанавливаю sing-box 1.11.1-1...${NC}"
            wget -O /tmp/sing-box_1.11.1-1_aarch64_generic.ipk "https://raw.githubusercontent.com/Vancltkin/singb/install-integration/sing-box_1.11.1-1_aarch64_generic.ipk"
            opkg install /tmp/sing-box_1.11.1-1_aarch64_generic.ipk
            ;;
        2)
            echo -e "${YELLOW}▶ Устанавливаю последнюю версию sing-box...${NC}"
            opkg install sing-box
            ;;
        *)
            echo -e "${RED}⚠ Неверный выбор. Пожалуйста, выберите снова.${NC}"
            ;;
    esac
}

# Меню выбора версии
separator
echo -e "${MAGENTA}Выберите версию sing-box для установки:${NC}"
echo -e "${GREEN}1)${NC} Установить sing-box 1.11.1-1"
echo -e "${GREEN}2)${NC} Установить последнюю версию sing-box"
echo

# Чтение выбора пользователя
read -p "$(echo -e "${CYAN}▷ Введите номер версии: ${NC}")" choice

# Установка выбранной версии
install_version $choice
echo -e "${GREEN}✓ Установка sing-box завершена${NC}\n"

separator
echo -e "${CYAN}► Настройка sing-box...${NC}"
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
echo -e "${GREEN}✓ Конфигурация применена${NC}\n"

echo -e "${YELLOW}► Отключаю сервис sing-box...${NC}"
service sing-box disable
echo -e "${GREEN}✓ Сервис отключен${NC}\n"

echo -e "${YELLOW}► Очищаю конфигурационный файл...${NC}"
echo '{}' > /etc/sing-box/config.json
echo -e "${GREEN}✓ Файл /etc/sing-box/config.json очищен${NC}\n"

separator
echo -e "${CYAN}► Создаю сетевой интерфейс proxy...${NC}"
uci set network.proxy=interface
uci set network.proxy.proto="none"
uci set network.proxy.device="singtun0"
uci commit network
service network restart
echo -e "${GREEN}✓ Сетевой интерфейс создан${NC}\n"

echo -e "${CYAN}► Настройка файрвола...${NC}"
uci add firewall zone
uci set firewall.@zone[-1].name="proxy"
uci set firewall.@zone[-1].forward="REJECT"
uci set firewall.@zone[-1].device="singtun0"
uci add firewall forwarding
uci set firewall.@forwarding[-1].dest="proxy"
uci set firewall.@forwarding[-1].src="lan"
uci commit firewall
service firewall reload
echo -e "${GREEN}✓ Правила файрвола применены${NC}\n"

# Новый блок автоматической настройки конфигурации
# Новый блок автоматической настройки конфигурации
AUTO_CONFIG_SUCCESS=0
separator
echo -e "${MAGENTA}▶ Настройка конфигурации sing-box${NC}"
read -p "$(echo -e "${CYAN}▷ Введите URL конфигурации (оставьте пустым для ручной настройки): ${NC}")" CONFIG_URL

if [ -n "$CONFIG_URL" ]; then
    echo -e "${YELLOW}▶ Загрузка конфигурации...${NC}"
    RAW_JSON=$(curl -fsS "$CONFIG_URL" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}▶ Проверка формата JSON...${NC}"
        FORMATTED_JSON=$(echo "$RAW_JSON" | jq '.' 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo "$FORMATTED_JSON" > /etc/sing-box/config.json
            echo -e "${GREEN}✓ Конфигурация успешно применена!${NC}"
            
            echo -e "${YELLOW}► Перезапуск сервиса...${NC}"
            service sing-box enable
            service sing-box restart
            echo -e "${GREEN}✓ Сервис успешно запущен!${NC}"
            AUTO_CONFIG_SUCCESS=1
        else
            echo -e "${RED}⚠ Ошибка: Некорректный JSON-формат!${NC}"
            echo -e "${YELLOW}▶ Переход к ручному редактированию...${NC}"
            nano /etc/sing-box/config.json
        fi
    else
        echo -e "${RED}⚠ Ошибка загрузки: ${RAW_JSON}${NC}"
        echo -e "${YELLOW}▶ Переход к ручному редактированию...${NC}"
        nano /etc/sing-box/config.json
    fi
else
    echo -e "${YELLOW}▶ Ручная настройка конфигурации...${NC}"
    nano /etc/sing-box/config.json
fi

# Проверка конфигурации ТОЛЬКО при ручной настройке
if [ "$AUTO_CONFIG_SUCCESS" -eq 0 ]; then
    while true; do
        separator
        read -p "$(echo -e "${CYAN}▷ Завершили настройку config.json? [y/N]: ${NC}")" yn
        case ${yn:-n} in
            [Yy]* )
                echo -e "${YELLOW}► Перезапускаю сервис...${NC}"
                service sing-box enable
                service sing-box restart
                echo -e "${GREEN}✓ Сервис успешно запущен!${NC}"
                break
                ;;
            [Nn]* )
                echo -e "${YELLOW}▶ Открываю редактор снова...${NC}"
                nano /etc/sing-box/config.json
                ;;
            * )
                echo -e "${RED}⚠ Неверный ввод, используйте y или n${NC}"
                ;;
        esac
    done
fi

# Остальная часть скрипта без изменений
# Создание дополнительных конфигов
echo -e "\n${CYAN}► Создаю резервные конфигурации...${NC}"
for i in 2 3; do
    if [ ! -f "/etc/sing-box/config${i}.json" ]; then
        echo '{}' > "/etc/sing-box/config${i}.json"
        echo -e "${GREEN}✓ Создан файл /etc/sing-box/config${i}.json${NC}"
    fi
done

separator
echo -e "${CYAN}► Устанавливаю singb UI...${NC}"
wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk 
chmod 0755 /root/luci-app-singb.ipk 
opkg install /root/luci-app-singb.ipk 
echo -e "${GREEN}✓ UI успешно установлен${NC}"

separator
echo -e "${YELLOW}► Глубокая очистка кэша интерфейса...${NC}"

# 1. Удаляем все известные кэш-файлы
echo -e "${CYAN}▷ Удаляю кэш Luci...${NC}"
find /tmp -name "luci-*cache*" -exec rm -f {} \; 2>/dev/null
rm -f /var/lib/uhttpd* 2>/dev/null

# 2. Перезагружаем системные сервисы
echo -e "${CYAN}▷ Перезапускаю сервисы...${NC}"
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd restart
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart
[ -x /etc/init.d/lighttpd ] && /etc/init.d/lighttpd restart

# 4. Форсируем обновление DNS
echo -e "${CYAN}▷ Обновляю DNS...${NC}"
killall -HUP dnsmasq 2>/dev/null

echo -e "${CYAN}▷ Исправляю права доступа...${NC}"
chmod 755 /www/luci-static/singb 2>/dev/null

separator
echo -e "${GREEN}✓ Глубокая очистка выполнена!${NC}"

separator
echo -e "\n${CYAN}► Отключаю IPv6 и применяю настройки...${NC}"
uci set 'network.lan.ipv6=0'
uci set 'network.wan.ipv6=0'
uci set 'dhcp.lan.dhcpv6=disabled'
/etc/init.d/odhcpd disable
uci commit
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci commit dhcp
/etc/init.d/odhcpd restart
uci set network.lan.delegate="0"
uci commit network
/etc/init.d/odhcpd disable
/etc/init.d/odhcpd stop
uci -q delete network.globals.ula_prefix
uci commit network
separator
echo -e "${GREEN}✓ Настройки применены! Соединение может временно прерваться.${NC}"
separator
echo -e "${GREEN}✔ Вы можете получить доступ к веб-интерфейсу по адресу:"
separator
echo -e "${WHITE}http://192.168.1.1/${NC}"
separator
echo -e "${BGBLUE}${WHITE}                    ВСЁ УСПЕШНО УСТАНОВЛЕНО!                    ${NC}"
separator
/etc/init.d/network restart


