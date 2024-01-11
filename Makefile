BASE_DIR		:= 	$(shell dirname $(lastword $(MAKEFILE_LIST)))
CROSS_COMPILE	:= ${BASE_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
CROSS_CM3		:= arm-linux-gnueabi-

UBOOT_SRC		:= u-boot
TFA_SRC			:= trusted-firmware-a
MBB_SRC			:= mox-boot-builder

${TFA_SRC}/build/a3700/release/flash-image.bin: ${UBOOT_SRC}/u-boot.bin ${MBB_SRC}/wtmi_app.bin FORCE
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
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE} gti_ccpe-88f3720_defconfig
	$(MAKE) -C ${UBOOT_SRC} CROSS_COMPILE=${CROSS_COMPILE} DEVICE_TREE=armada-3720-ccpe

clean:
	-$(MAKE) -C ${UBOOT_SRC} clean
	-$(MAKE) -C ${MBB_SRC} clean
	-$(MAKE) -C ${TFA_SRC} distclean

.PHONY: clean FORCE
FORCE:;
