# full path to this file
BASE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST)))).

# make/compiler settings
CROSS_COMPILE	:= aarch64-linux-gnu-
CROSS_CM3		:= arm-linux-gnueabi-

# paths to source code
UBOOT_SRC	:= ${BASE_DIR}/u-boot
TFA_SRC		:= ${BASE_DIR}/trusted-firmware-a
MBB_SRC		:= ${BASE_DIR}/mox-boot-builder
WTP_SRC		:= ${BASE_DIR}/A3700-utils-marvell
MV_DDR_SRC	:= ${BASE_DIR}/mv-ddr-marvell

# see https://trustedfirmware-a.readthedocs.io/en/latest/plat/marvell/armada/build.html
# and U-Boot source for device-specific settings. defaults are for ESPRESSObin Ultra
CLOCKSPRESET ?= CPU_1200_DDR_750
DDR_TOPOLOGY ?= 5
UBOOT_CONFIG ?= mvebu_espressobin_ultra-88f3720_defconfig

all: bubt_image

u-boot: ${UBOOT_SRC}/u-boot.bin
wtmi_app: ${MBB_SRC}/wtmi_app.bin
bubt_image: ${TFA_SRC}/build/a3700/release/flash-image.bin

${TFA_SRC}/build/a3700/release/flash-image.bin: u-boot wtmi_app FORCE
	$(MAKE) -C ${TFA_SRC} \
		CROSS_COMPILE=${CROSS_COMPILE} \
		PLAT=a3700 \
		USE_COHERENT_MEM=0 \
		MV_DDR_PATH=${MV_DDR_SRC} \
		DDR_TOPOLOGY=${DDR_TOPOLOGY} \
		CLOCKSPRESET=${CLOCKSPRESET} \
		WTP=${WTP_SRC} \
		CRYPTOPP_LIBDIR=/usr/lib/ \
		CRYPTOPP_INCDIR=/usr/include/crypto++/ \
		BL33=${UBOOT_SRC}/u-boot.bin \
		WTMI_IMG=${MBB_SRC}/wtmi_app.bin \
		mrvl_flash

${MBB_SRC}/wtmi_app.bin: FORCE
	$(MAKE) -C ${MBB_SRC} \
		CROSS_COMPILE=${CROSS_COMPILE} \
		CROSS_CM3=${CROSS_CM3} \
		wtmi_app.bin

${UBOOT_SRC}/u-boot.bin: FORCE
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE} ${UBOOT_CONFIG}
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE}

clean:
	-$(MAKE) -C ${UBOOT_SRC} clean
	-$(MAKE) -C ${MBB_SRC} clean
	-$(MAKE) -C ${TFA_SRC} distclean

gitclean:
	@git -C ${WTP_SRC} clean -fd
	@git -C ${MV_DDR_SRC} clean -f

.PHONY: u-boot wtmi_app bubt_image clean gitclean FORCE
FORCE:;
