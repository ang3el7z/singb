#!/bin/sh

# Обновление репозиториев и установка зависимостей
echo "Устанавливаю зависимости..."
opkg update && opkg install openssh-sftp-server nano curl

echo "Выберите версию sing-box для установки:"
echo "1) Установить версию 1.9.7-1"
echo "2) Установить последнюю версию (latest)"
read -p "Введите номер варианта: " choice

case "$choice" in
    1)
        echo "Скачиваю и устанавливаю sing-box 1.9.7-1..."
        wget -O /tmp/sing-box_1.9.7-1_aarch64_cortex-a53.ipk "https://raw.githubusercontent.com/Vancltkin/singb/main/sing-box_1.9.7-1_aarch64_cortex-a53.ipk"
        opkg install /tmp/sing-box_1.9.7-1_aarch64_cortex-a53.ipk
        ;;
    2)
        echo "Устанавливаю последнюю версию sing-box..."
        opkg install sing-box
        ;;
    *)
        echo "Неверный ввод. Пожалуйста, выберите 1 или 2."
        exit 1
        ;;
esac

echo "Установка завершена!"

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

# Открытие конфигурационного файла для редактирования
echo "Открываю конфигурационный файл для редактирования..."
nano /etc/sing-box/config.json

# Запрос на подтверждение, что файл настроен правильно
while true; do
    read -p "Вы настроили файл /etc/sing-box/config.json ? (y/n, по умолчанию y): " yn
    yn=${yn:-y}  # Если пользователь не ввел ничего, по умолчанию будет 'y'
    
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
        * ) 
            echo "Вы настроили файл /etc/sing-box/config.json. Пожалуйста, введите y (да) или n (нет)."
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
echo "Установка singb"
wget -O /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart

echo "Обновляем UI"
rm -f /var/luci-indexcache*
rm -f /tmp/luci-indexcache*

# Перезагружаем rpcd, если он доступен
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd reload

# Перезагружаем uhttpd, если он доступен
[ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart
