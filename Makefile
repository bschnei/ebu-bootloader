# full path to this file
BASE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST)))).

# make/compiler settings
CROSS_COMPILE	:= ${BASE_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
CROSS_CM3		:= arm-linux-gnueabi-

# paths to source code
UBOOT_SRC	:= ${BASE_DIR}/u-boot
TFA_SRC		:= ${BASE_DIR}/trusted-firmware-a
MBB_SRC		:= ${BASE_DIR}/mox-boot-builder

all: bubt_image

u-boot: ${UBOOT_SRC}/u-boot.bin
wtmi_app: ${MBB_SRC}/wtmi_app.bin
bubt_image: ${TFA_SRC}/build/a3700/release/flash-image.bin

${TFA_SRC}/build/a3700/release/flash-image.bin: u-boot wtmi_app FORCE
	$(MAKE) -C ${TFA_SRC} \
		CROSS_COMPILE=${CROSS_COMPILE} \
		PLAT=a3700 \
		USE_COHERENT_MEM=0 \
		MV_DDR_PATH=${BASE_DIR}/mv-ddr-marvell \
		DDR_TOPOLOGY=5 \
		CLOCKSPRESET=CPU_1000_DDR_800 \
		WTP=${BASE_DIR}/A3700-utils-marvell \
		CRYPTOPP_PATH=${BASE_DIR}/cryptopp \
		BL33=${UBOOT_SRC}/u-boot.bin \
		WTMI_IMG=${MBB_SRC}/wtmi_app.bin \
		mrvl_flash

${MBB_SRC}/wtmi_app.bin: FORCE
	$(MAKE) -C ${MBB_SRC} CROSS_CM3=${CROSS_CM3} wtmi_app.bin

${UBOOT_SRC}/u-boot.bin: FORCE
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE} mvebu_espressobin-88f3720_defconfig
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE}

clean:
	-$(MAKE) -C ${UBOOT_SRC} clean
	-$(MAKE) -C ${MBB_SRC} clean
	-$(MAKE) -C ${TFA_SRC} distclean

.PHONY: clean FORCE
FORCE:;
