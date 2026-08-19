include $(TOPDIR)/rules.mk

PKG_NAME:=neighbord
PKG_RELEASE:=1

PKG_LICENSE:=GPL-2.0-only

include $(INCLUDE_DIR)/package.mk

define Package/neighbord
  SECTION:=net
  CATEGORY:=Network
  TITLE:=802.11k Neighbor Report synchronizer
  DEPENDS:=+ucode +ucode-mod-ubus +ucode-mod-uloop +ucode-mod-socket +ucode-mod-uci
  PKGARCH:=all
endef

define Package/neighbord/description
 Synchronize hostapd 802.11k Neighbor Reports between local BSSes and
 OpenWrt access points on the same LAN.
endef

define Build/Compile
	:
endef

define Package/neighbord/conffiles
/etc/config/neighbord
endef

define Package/neighbord/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d $(1)/usr/sbin
	$(INSTALL_CONF) ./files/etc/config/neighbord $(1)/etc/config/neighbord
	$(INSTALL_BIN) ./files/etc/init.d/neighbord $(1)/etc/init.d/neighbord
	$(INSTALL_BIN) ./files/usr/sbin/neighbord $(1)/usr/sbin/neighbord
endef

$(eval $(call BuildPackage,neighbord))
