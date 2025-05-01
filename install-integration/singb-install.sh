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
echo -e "${CYAN}► Устанавливаю зависимости...${NC}"
opkg update && opkg install openssh-sftp-server nano curl
echo -e "${GREEN}✓${NC}\n"
separator

echo -e "${CYAN}► Устанавливаю последнюю версию sing-box...${NC}"
opkg install sing-box
echo -e "${GREEN}✓${NC}\n"

# Конфигурация sing-box
echo -e "${CYAN}► Настройка sing-box...${NC}"
echo "Настройка sing-box..."
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box
echo -e "${GREEN}✓${NC}\n"

# Отключение сервиса sing-box
echo "Отключаю сервис sing-box..."
service sing-box disable

# Очистка конфигурационного файла sing-box
echo "Очищаю конфигурационный файл /etc/sing-box/config.json..."
echo '{}' > /etc/sing-box/config.json
separator

# Создание нового интерфейса "proxy"
echo -e "${CYAN}► Создаю новый интерфейс proxy...${NC}"
uci set network.proxy=interface
uci set network.proxy.proto="none"
uci set network.proxy.device="singtun0"
uci set network.proxy.defaultroute="0"
uci set network.proxy.delegate="0"
uci set network.proxy.peerdns="0"
uci set network.proxy.auto="1"
uci commit network
service network restart
echo -e "${GREEN}✓${NC}\n"

# Настройка правил файрвола
echo -e "${CYAN}► Настройка правил файрвола...${NC}"
uci add firewall zone
uci set firewall.@zone[-1].name="proxy"
uci set firewall.@zone[-1].forward="REJECT"
uci set firewall.@zone[-1].output="ACCEPT"
uci set firewall.@zone[-1].input="ACCEPT"
uci set firewall.@zone[-1].masq="1"
uci set firewall.@zone[-1].mtu_fix="1"
uci set firewall.@zone[-1].device="singtun0"
uci set firewall.@zone[-1].family="ipv4"
uci add_list firewall.@zone[-1].network="singtun0"
uci add firewall forwarding
uci set firewall.@forwarding[-1].dest="proxy"
uci set firewall.@forwarding[-1].src="lan"
uci set firewall.@forwarding[-1].family="ipv4"
uci commit firewall
service firewall reload
echo -e "${GREEN}✓${NC}\n"

# Открытие конфигурационного файла для редактирования
echo "Открываю конфигурационный файл для редактирования..."
nano /etc/sing-box/config.json

# Запрос на подтверждение, что файл настроен правильно
while true; do
    read -p "Вы настроили файл /etc/sing-box/config.json ? (y/n/пропустить, по умолчанию пропустить): " yn
    yn=${yn:-skip}  # Если пользователь не ввел ничего, по умолчанию будет 'skip'
    
    case $yn in
        [Yy]* ) 
            echo "После записи /etc/sing-box/config.json перезапускаем службу"
            service sing-box enable
            service sing-box restart
            break
            ;;
        [Nn]* ) 
            echo "Перезапускаю редактор nano для редактирования конфигурации..."
            nano /etc/sing-box/config.json
            ;;
        [Ss]* | "" ) 
            echo "Пропуск настройки конфигурации."
            break
            ;;
        * ) 
            echo "Пожалуйста, введите y (да), n (нет) или нажмите Enter для пропуска."
            ;;
    esac
done

# Проверяем, существует ли файл config2.json, если нет - создаем пустой файл
if [ ! -f /etc/sing-box/config2.json ]; then
    echo "{}" > /etc/sing-box/config2.json
    echo "Created /etc/sing-box/config2.json"
fi

# Проверяем, существует ли файл config3.json, если нет - создаем пустой файл
if [ ! -f /etc/sing-box/config3.json ]; then
    echo "{}" > /etc/sing-box/config3.json
    echo "Created /etc/sing-box/config3.json"
fi

# Установка singb-ui
separator
echo -e "${CYAN}► Установка singb...${NC}"
wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart
echo -e "${GREEN}✓${NC}\n"

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
echo -e "${GREEN}✓${NC}"

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
