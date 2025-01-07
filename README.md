# singb
wget -O /root/init.sh https://raw.githubusercontent.com/Vancltkin/singb/main/init.sh && chmod 0755 /root/init.sh && sh /root/init.sh

wget -O  /root/luci-app-singb.ipk https://github.com/Vancltkin/singb/releases/latest/download/luci-app-singb_0.0.1_all.ipk && chmod 0755 /root/luci-app-singb.ipk && opkg update && opkg install /root/luci-app-singb.ipk && /etc/init.d/uhttpd restart

