################################################################################
#
# qutselect
#
################################################################################

QUTSELECT_VERSION = 2.4
QUTSELECT_SITE = $(call github,Rockyb0a,qutselect,$(QUTSELECT_VERSION))
QUTSELECT_LICENSE = LGPL-3.0
QUTSELECT_LICENSE_FILES = LICENSE
QUTSELECT_DEPENDENCIES = qt5base
QUTSELECT_CONF_OPTS = -DCMAKE_INSTALL_PREFIX:PATH=/

define QUTSELECT_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/bin/qutselect-$(QUTSELECT_VERSION) $(TARGET_DIR)/bin/qutselect
	#$(INSTALL) -D -m 0644 $(@D)/qutselect.slist $(TARGET_DIR)/bin/
	#$(INSTALL) -D -m 0644 $(@D)/qutselect.motd $(TARGET_DIR)/bin/
	cp -R $(@D)/scripts $(TARGET_DIR)/bin/
endef

$(eval $(cmake-package))
