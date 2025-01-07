#!/bin/bash

# Установка зависимостей
opkg update && opkg install openssh-sftp-server nano curl sing-box

# Включаем sing-box
uci set sing-box.main.enabled="1"
uci set sing-box.main.user="root"
uci commit sing-box

# Останавливаем сервис sing-box
service sing-box disable

# Запрашиваем конфигурацию от пользователя
echo "Введите конфигурацию в формате JSON:"

# Чтение ввода от пользователя
read -r user_config

# Очистка файла конфигурации
echo "{}" > /etc/sing-box/config.json

# Запись введенной конфигурации в файл
echo "$user_config" > /etc/sing-box/config.json

# Создание нового интерфейса "proxy"
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

# Запуск сервиса sing-box
service sing-box enable
service sing-box restart

echo "Конфигурация успешно применена!"
