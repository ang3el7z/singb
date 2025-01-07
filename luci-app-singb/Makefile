include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-signb
PKG_VERSION:=0.2.5
PKG_RELEASE:=1

LUCI_TITLE:=LuCI signb app
LUCI_DEPENDS:=+luci-base +signb
LUCI_PKGARCH:=all
LUCI_LANG.ru:=Русский (Russian)
LUCI_LANG.en:=English

PKG_LICENSE:=GPL-2.0-or-later
PKG_MAINTAINER:=ITDog <signb@signb.signb>

LUCI_LANGUAGES:=en ru

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
