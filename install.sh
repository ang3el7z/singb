#!/bin/sh

# Обновление репозиториев и установка зависимостей
echo "Устанавливаю зависимости..."
opkg update && opkg install openssh-sftp-server nano curl sing-box

# Конфигурация sing-box
echo "Настройка sing-box..."
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box

# Отключение сервиса sing-box
echo "Отключаю сервис sing-box..."
service sing-box disable

# Очистка конфигурационного файла sing-box
echo "Очищаю конфигурационный файл /etc/sing-box/config.json..."
echo '{}' > /etc/sing-box/config.json

# Создание нового интерфейса "proxy"
echo "Создаю новый интерфейс proxy..."
uci set network.proxy=interface
uci set network.proxy.proto="none"
uci set network.proxy.device="singtun0"
uci set network.proxy.defaultroute="0"
uci set network.proxy.delegate="0"
uci set network.proxy.peerdns="0"
uci set network.proxy.auto="1"
uci commit network
service network restart

# Настройка правил файрвола
echo "Настройка правил файрвола..."
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

# Установка singb-ui
echo "Установка singb"
wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb_0.0.1_all.ipk && 
chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart

# Открытие конфигурационного файла для редактирования
echo "Открываю конфигурационный файл для редактирования..."
nano /etc/sing-box/config.json

# Комментарий по выполнению следующих шагов
echo "Конфигурация завершена. После записи /etc/sing-box/config.json перезапускаем службу"
service sing-box enable
service sing-box restart
