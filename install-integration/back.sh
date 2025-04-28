#!/bin/sh

# Функция для отрисовки разделителя
separator() {
    echo "======================================================="
}

echo "Начинаем откат изменений..."
separator

# 1. Остановка и удаление сервиса sing-box
echo "▶ Останавливаю и удаляю сервис sing-box..."
service sing-box stop 2>/dev/null
service sing-box disable 2>/dev/null
/etc/init.d/sing-box disable 2>/dev/null
rm /etc/init.d/sing-box 2>/dev/null

# 2. Удаление пакетов
echo "▶ Удаляю установленные пакеты..."
opkg remove --autoremove sing-box luci-app-singb 2>/dev/null

# 3. Удаление конфигураций
echo "▶ Удаляю файлы конфигурации..."
rm -rf /etc/sing-box 2>/dev/null

# 4. Откат сетевых настроек
echo "▶ Восстанавливаю сетевые настройки..."
uci -q delete network.proxy
uci -q delete network.globals.ula_prefix
uci -q set network.lan.delegate="1"
uci -q delete network.lan.ipv6
uci -q delete network.wan.ipv6
uci commit network

# 5. Восстановление firewall
echo "▶ Восстанавливаю настройки фаервола..."
uci -q delete firewall.@zone[-1] 2>/dev/null
uci -q delete firewall.@forwarding[-1] 2>/dev/null
uci commit firewall

# 6. Восстановление DHCP
echo "▶ Восстанавливаю DHCP сервер..."
uci -q delete dhcp.lan.dhcpv6
uci -q delete dhcp.lan.ra
uci set dhcp.lan.dhcpv6="server"
uci set dhcp.lan.ra="server"
/etc/init.d/odhcpd enable 2>/dev/null
/etc/init.d/odhcpd start 2>/dev/null
uci commit dhcp

# 7. Удаление Luci-приложения
echo "▶ Удаляю веб-интерфейс..."
rm -rf /www/luci-static/singb 2>/dev/null
rm -f /root/luci-app-singb.ipk 2>/dev/null

# 8. Перезагрузка сервисов
echo "▶ Перезагружаю системные сервисы..."
service network restart 2>/dev/null
service firewall reload 2>/dev/null
/etc/init.d/dnsmasq restart 2>/dev/null
/etc/init.d/uhttpd restart 2>/dev/null

separator
echo "✔ Откат изменений завершен! Рекомендуется перезагрузить устройство."
echo "Команда для перезагрузки: reboot"
separator
