![{47390F65-F6C3-4571-8075-63884812D9A2}](https://github.com/user-attachments/assets/95ae6f13-8763-4246-9ec2-30056f3de934)


# sing-box templates (Шаблон для бота)

https://github.com/Vancltkin/singb/blob/main/openwrt.json

# Установка singbox + singb
wget -O /root/install.sh https://raw.githubusercontent.com/Vancltkin/singb/main/install.sh && chmod 0755 /root/install.sh && sh /root/install.sh


# Установка singb (Необходимо установить сначала singbox)
wget -O  /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart


