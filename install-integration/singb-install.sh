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

echo -e "${CYAN}► Обновляем список пакетов...${NC}"
opkg update && opkg install openssh-sftp-server nano curl jq
echo -e "${GREEN}✓ Успешно обновлены${NC}\n"

separator
echo -e "${CYAN}► Далее устанавливаем необходимые для работы sing-box модули ядра и пакет совместимости с iptables...${NC}"
opkg install kmod-inet-diag kmod-netlink-diag kmod-tun iptables-nft
echo -e "${GREEN}✓ Успешно установлены${NC}\n"

echo -e "${CYAN}► Далее переходим к установке sing-box...${NC}"
 opkg install sing-box
echo -e "${GREEN}✓ Успешно ${NC}\n"

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
# Создаем зону "proxy"
uci set firewall.proxy=zone
uci set firewall.proxy.name='proxy'
uci add_list firewall.proxy.network='tunnel'  # Добавляем элемент в список network
uci set firewall.proxy.forward='REJECT'
uci set firewall.proxy.output='ACCEPT'
uci set firewall.proxy.input='REJECT'
uci set firewall.proxy.masq='1'
uci set firewall.proxy.mtu_fix='1'
uci set firewall.proxy.device='singtun0'
uci set firewall.proxy.family='ipv4'

# Создаем правило форвардинга "lan-proxy"
uci set firewall.lan_proxy=forwarding
uci set firewall.lan_proxy.name='lan-proxy'
uci set firewall.lan_proxy.dest='proxy'
uci set firewall.lan_proxy.src='lan'
uci set firewall.lan_proxy.family='ipv4'

# Сохраняем изменения и применяем
uci commit firewall
/etc/init.d/firewall reload
echo -e "${GREEN}✓ Правила файрвола применены${NC}\n"


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
