BUILDROOT_VERSION=2021.08.3
BUILDROOT_EXTERNAL=buildroot-external
DEFCONFIG_DIR=$(BUILDROOT_EXTERNAL)/configs
DATE=$(shell date +%Y%m%d)
PRODUCT=
PRODUCT_VERSION=${DATE}
PRODUCTS:=$(sort $(notdir $(patsubst %_defconfig,%,$(wildcard $(DEFCONFIG_DIR)/*_defconfig))))
BR2_DL_DIR="../download"
BR2_CCACHE_DIR="${HOME}/.buildroot-ccache"
BR2_JLEVEL=0

ifneq ($(PRODUCT),)
	PRODUCTS:=$(PRODUCT)
else
	PRODUCT:=$(firstword $(PRODUCTS))
endif

.NOTPARALLEL: $(PRODUCTS) $(addsuffix -release, $(PRODUCTS)) $(addsuffix -clean, $(PRODUCTS)) build-all clean-all release-all
.PHONY: all build release clean cleanall distclean help updatePkg

all: help

buildroot-$(BUILDROOT_VERSION).tar.bz2:
	@echo "[downloading buildroot-$(BUILDROOT_VERSION).tar.bz2]"
	wget https://buildroot.org/downloads/buildroot-$(BUILDROOT_VERSION).tar.bz2
	wget https://buildroot.org/downloads/buildroot-$(BUILDROOT_VERSION).tar.bz2.sign
	cat buildroot-$(BUILDROOT_VERSION).tar.bz2.sign | grep SHA1: | sed 's/^SHA1: //' | shasum -c

buildroot-$(BUILDROOT_VERSION): | buildroot-$(BUILDROOT_VERSION).tar.bz2
	@echo "[patching buildroot-$(BUILDROOT_VERSION)]"
	if [ ! -d $@ ]; then tar xf buildroot-$(BUILDROOT_VERSION).tar.bz2; for p in $(sort $(wildcard buildroot-patches/*.patch)); do echo "\nApplying $${p}"; patch -d buildroot-$(BUILDROOT_VERSION) -p1 < $${p} || exit 127; [ ! -x $${p%.*}.sh ] || $${p%.*}.sh buildroot-$(BUILDROOT_VERSION); done; fi

build-$(PRODUCT): | buildroot-$(BUILDROOT_VERSION) download
	mkdir -p build-$(PRODUCT)

download: buildroot-$(BUILDROOT_VERSION)
	mkdir -p download

build-$(PRODUCT)/.config: | build-$(PRODUCT)
	@echo "[config $@]"
	cd build-$(PRODUCT) && $(MAKE) O=$(shell pwd)/build-$(PRODUCT) -C ../buildroot-$(BUILDROOT_VERSION) BR2_EXTERNAL=../$(BUILDROOT_EXTERNAL) BR2_DL_DIR=$(BR2_DL_DIR) BR2_CCACHE_DIR=$(BR2_CCACHE_DIR) BR2_JLEVEL=$(BR2_JLEVEL) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION) $(PRODUCT)_defconfig

build-all: $(PRODUCTS)
$(PRODUCTS): %:
	@echo "[build: $@]"
	@$(MAKE) PRODUCT=$@ PRODUCT_VERSION=$(PRODUCT_VERSION) build

build: | buildroot-$(BUILDROOT_VERSION) build-$(PRODUCT)/.config
	@echo "[build: $(PRODUCT)]"
ifneq ($(FAKE_BUILD),true)
	cd build-$(PRODUCT) && $(MAKE) O=$(shell pwd)/build-$(PRODUCT) -C ../buildroot-$(BUILDROOT_VERSION) BR2_EXTERNAL=../$(BUILDROOT_EXTERNAL) BR2_DL_DIR=$(BR2_DL_DIR) BR2_CCACHE_DIR=$(BR2_CCACHE_DIR) BR2_JLEVEL=$(BR2_JLEVEL) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION)
else
	$(eval BOARD := $(shell echo $(PRODUCT) | cut -d'_' -f2-))
	# Dummy build - mainly for testing CI
	echo -n "FAKE_BUILD - generating fake release archives..."
	mkdir -p build-$(PRODUCT)/images
	for f in `cat release/updatepkg/$(PRODUCT)/files-images.txt`; do echo DUMMY >build-$(PRODUCT)/images/$${f}; done
	mkdir -p /tmp/oci
	tar -cf /tmp/oci/layer.tar LICENSE
	tar -C /tmp -cvf thinRoot-$(PRODUCT_VERSION)-$(BOARD).tar oci
	mv thinRoot-$(PRODUCT_VERSION)-$(BOARD).tar build-$(PRODUCT)/images/
	rm -rf /tmp/oci
	echo DUMMY >build-$(PRODUCT)/images/sdcard.img
	echo DUMMY >build-$(PRODUCT)/images/thinRoot.ova
endif

release-all: $(addsuffix -release, $(PRODUCTS))
$(addsuffix -release, $(PRODUCTS)): %:
	@$(MAKE) PRODUCT=$(subst -release,,$@) PRODUCT_VERSION=$(PRODUCT_VERSION) release

release: build
	@echo "[creating release: $(PRODUCT)]"
	$(eval BOARD_DIR := $(BUILDROOT_EXTERNAL)/board/$(PRODUCT))
	if [ -x $(BOARD_DIR)/post-release.sh ]; then $(BOARD_DIR)/post-release.sh $(BOARD_DIR) ${PRODUCT} ${PRODUCT_VERSION}; fi

clean-all: $(addsuffix -clean, $(PRODUCTS))
$(addsuffix -clean, $(PRODUCTS)): %:
	@$(MAKE) PRODUCT=$(subst -clean,,$@) PRODUCT_VERSION=$(PRODUCT_VERSION) clean

clean:
	@echo "[clean $(PRODUCT)]"
	@rm -rf build-$(PRODUCT)

distclean: clean-all
	@echo "[distclean]"
	@rm -rf buildroot-$(BUILDROOT_VERSION)
	@rm -f buildroot-$(BUILDROOT_VERSION).tar.bz2 buildroot-$(BUILDROOT_VERSION).tar.bz2.sign
	@rm -rf download

.PHONY: menuconfig
menuconfig: buildroot-$(BUILDROOT_VERSION) build-$(PRODUCT)/.config
	cd build-$(PRODUCT) && $(MAKE) O=$(shell pwd)/build-$(PRODUCT) -C ../buildroot-$(BUILDROOT_VERSION) BR2_EXTERNAL=../$(BUILDROOT_EXTERNAL) BR2_DL_DIR=$(BR2_DL_DIR) BR2_CCACHE_DIR=$(BR2_CCACHE_DIR) BR2_JLEVEL=$(BR2_JLEVEL) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION) menuconfig

.PHONY: xconfig
xconfig: buildroot-$(BUILDROOT_VERSION) build-$(PRODUCT)/.config
	cd build-$(PRODUCT) && $(MAKE) O=$(shell pwd)/build-$(PRODUCT) -C ../buildroot-$(BUILDROOT_VERSION) BR2_EXTERNAL=../$(BUILDROOT_EXTERNAL) BR2_DL_DIR=$(BR2_DL_DIR) BR2_CCACHE_DIR=$(BR2_CCACHE_DIR) BR2_JLEVEL=$(BR2_JLEVEL) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION) xconfig

.PHONY: savedefconfig
savedefconfig: buildroot-$(BUILDROOT_VERSION) build-$(PRODUCT)
	cd build-$(PRODUCT) && $(MAKE) O=$(shell pwd)/build-$(PRODUCT) -C ../buildroot-$(BUILDROOT_VERSION) BR2_EXTERNAL=../$(BUILDROOT_EXTERNAL) BR2_DL_DIR=$(BR2_DL_DIR) BR2_CCACHE_DIR=$(BR2_CCACHE_DIR) BR2_JLEVEL=$(BR2_JLEVEL) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION) savedefconfig BR2_DEFCONFIG=../$(DEFCONFIG_DIR)/$(PRODUCT)_defconfig

# Create a fallback target (%) to forward all unknown target calls to the build Makefile.
# This includes:
#   linux-menuconfig
#   linux-update-defconfig
#   busybox-menuconfig
#   busybox-update-config
#   uboot-menuconfig
#   uboot-update-defconfig
linux-menuconfig linux-update-defconfig busybox-menuconfig busybox-update-config uboot-menuconfig uboot-update-defconfig:
	@echo "[$@ $(PRODUCT)]"
	@$(MAKE) -C build-$(PRODUCT) PRODUCT=$(PRODUCT) PRODUCT_VERSION=$(PRODUCT_VERSION) $@

help:
	@echo "thinRoot Build Environment"
	@echo
	@echo "Usage:"
	@echo "  $(MAKE) <product>: build+create image for selected product"
	@echo "  $(MAKE) build-all: run build for all supported products"
	@echo
	@echo "  $(MAKE) <product>-release: build+create release archive for product"
	@echo "  $(MAKE) release-all: build+create release archive for all supported products"
	@echo
	@echo "  $(MAKE) <product>-clean: remove build directory for product"
	@echo "  $(MAKE) clean-all: remove build directories for all supproted platforms"
	@echo
	@echo "  $(MAKE) distclean: clean everything (all build dirs and buildroot sources)"
	@echo
	@echo "Supported products: $(PRODUCTS)"
