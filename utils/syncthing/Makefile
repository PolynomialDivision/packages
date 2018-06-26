include $(TOPDIR)/rules.mk

PKG_NAME:=syncthing
PKG_VERSION:=1.2.0
PKG_RELEASE:=1

PKG_SOURCE:=syncthing-source-v$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://github.com/syncthing/syncthing/releases/download/v$(PKG_VERSION)
PKG_HASH:=0339877effdcf3bf8aa7d4d1e50b878992792e4752ff778f27788bf71eccecd0

PKG_MAINTAINER:=Paul Spooren <mail@aparcar.org>
PKG_LICENSE:=MPL-2.0
PKG_LICENSE_FILES:=LICENSE
PKG_CPE_ID:=cpe:/a:syncthing:syncthing

PKG_BUILD_DEPENDS:=golang/host
PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

PKG_UNPACK:=$(TAR) -C $(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION) --strip-components=1 -xzf $(DL_DIR)/$(PKG_SOURCE)

GO_PKG:=github.com/syncthing/syncthing/
GO_PKG_BUILD_PKG:=github.com/syncthing/syncthing/cmd/syncthing/
GO_PKG_INSTALL_EXTRA:=^gui/

include $(INCLUDE_DIR)/package.mk
include ../../lang/golang/golang-package.mk

define Package/syncthing/Default
  TITLE:=Continuous file synchronization program
  URL:=https://syncthing.net
  DEPENDS:=$(GO_ARCH_DEPENDS)
endef

GO_PKG_LDFLAGS_X:=main.Version=v$(PKG_VERSION) main.BuildUser=openwrt main.BuildHost=openwrt main.BuildStamp=$(SOURCE_DATE_EPOCH) build.noupgrade=1

define Package/syncthing
  $(call Package/syncthing/Default)
  SECTION:=utils
  CATEGORY:=Utilities
endef

define Build/Compile
  $(call GoPackage/Build/Compile,-tags noupgrade)
endef

define Package/syncthing/conffiles
/etc/config/syncthing
/etc/syncthing
endef

define Package/syncthing/description
Syncthing replaces proprietary sync and cloud services with something open,
trustworthy and decentralized. Your data is your data alone and you deserve to
choose where it is stored, if it is shared with some third party and how it's
transmitted over the Internet.
endef

define Package/syncthing/install
	$(call GoPackage/Package/Install/Bin,$(1))

	$(CP) ./files/* $(1)/
endef

$(eval $(call GoBinPackage,syncthing))
$(eval $(call BuildPackage,syncthing))
