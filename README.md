
# Установка singbox + singb
wget -O /root/install.sh https://raw.githubusercontent.com/Vancltkin/singb/main/install.sh && chmod 0755 /root/install.sh && sh /root/install.sh




# Установка singb (Необходимо установить сначала singbox)
wget -O  /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb_0.0.1_all.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart


# Установка singbox + singb (НЕ УСТАНАВЛИВАТЬ!)
wget -O /root/installDev.sh https://raw.githubusercontent.com/Vancltkin/singb/main/installDev.sh && chmod 0755 /root/install.sh && sh /root/install.sh
