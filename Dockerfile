FROM openwrt/sdk:x86_64-v23.05.5

RUN ./scripts/feeds update -a && ./scripts/feeds install luci-base && mkdir -p /builder/package/feeds/utilites/ && mkdir -p /builder/package/feeds/luci/

COPY ./luci-app-signb /builder/package/feeds/luci/luci-app-signb

RUN make defconfig && make package/luci-app-signb/compile V=s -j4
