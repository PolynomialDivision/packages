#
# Copyright (C) 2006-2016 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=horst
PKG_VERSION:=2019-05-20
PKG_RELEASE:=3

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/br101/horst.git
PKG_SOURCE_VERSION:=4b048f854683843bdee48808b93e84250e41bbd3
PKG_MIRROR_HASH:=dbeea49d4ce56bee636f092a58be9ac7ae0f8c4296648b4e8f2fa3566e246c0d

PKG_MAINTAINER:=Bruno Randolf <br1@einfach.org>
PKG_LICENSE:=GPL-2.0+
PKG_LICENSE_FILES:=LICENSE

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

MAKE_FLAGS += DEBUG=0 LIBNL=tiny LIBUWIFI=
TARGET_CFLAGS += -D_GNU_SOURCE

define Package/horst
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Wireless
	DEPENDS:=+libncurses +libnl-tiny +libuwifi
	MAINTAINER:=Bruno Randolf <br1@einfach.org>
	TITLE:=Highly Optimized 802.11 Radio Scanning Tool
	URL:=http://br1.einfach.org/tech/horst/
endef

define Package/horst/description
	[horst] is a scanning and analysis tool for 802.11 wireless networks
	and especially IBSS (ad-hoc) mode and mesh networks (OLSR).
endef

define Package/horst/conffiles
/etc/config/horst
endef

define Package/horst/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/build/horst $(1)/usr/sbin/
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/horst.sh $(1)/usr/sbin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./horst.init $(1)/etc/init.d/horst
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./horst.config $(1)/etc/config/horst
endef

$(eval $(call BuildPackage,horst))
