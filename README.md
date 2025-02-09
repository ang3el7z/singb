![{47390F65-F6C3-4571-8075-63884812D9A2}](https://github.com/user-attachments/assets/95ae6f13-8763-4246-9ec2-30056f3de934)


# sing-box templates (Шаблон для бота)

https://github.com/Vancltkin/singb/blob/main/openwrt_1.9.7-1.json

# Установка singbox + singb
wget -O /root/install.sh https://raw.githubusercontent.com/Vancltkin/singb/main/install.sh && chmod 0755 /root/install.sh && sh /root/install.sh


# Установка singb (Необходимо установить сначала singbox)
wget -O  /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart

# Other (Если не появился пункт или после обновы, мб когда нибудь фиксану нормально)
![CleanShot 2025-01-21 at 11 05 26](https://github.com/user-attachments/assets/fa42cba3-1e4d-4cc9-8eb5-4f5020a0b7bf)
