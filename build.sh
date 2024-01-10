#!/usr/bin/env bash

ROOT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# cross compile settings for make
export ARCH=arm64
export CROSS_COMPILE=${ROOT_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

# Marvell's default assumption lines up with Ubuntu's package name for the
# 32-bit ARM compiler. Set explicitly or modify as needed.
#export CROSS_CM3=/usr/bin/arm-linux-gnueabi-

function build_bootloader {

    ### BUILD U-BOOT ###
    local u_boot=${ROOT_DIR}/u-boot
    make -C ${u_boot} mrproper

    # add custom device tree source
    cp armada-3720-espressobin-ultra.dts ${u_boot}/arch/arm/dts/

    # add custom device default config file
    cp mvebu_espressobin_ultra-88f3720_defconfig ${u_boot}/configs/

    # build full .config and then the BL33 image
    make -C ${u_boot} mvebu_espressobin_ultra-88f3720_defconfig
    make -C ${u_boot} u-boot.bin

    # build CZ.NIC's WTMI application
    local mbb=${ROOT_DIR}/mox-boot-builder
    make -C ${mbb} CROSS_CM3=arm-linux-gnueabi- clean wtmi_app.bin

    # see README
    local cpu_speed=1000

    # DDR clock speed is a function of cpu_speed
    local ddr_speed=800
    if [ "$cpu_speed" == 1200 ]; then
        ddr_speed=750
    fi

    # path to A3700 git repo (must be a git repo)
    local a3700_utils=${ROOT_DIR}/A3700-utils-marvell

    # clean a3700-utils image to prevent using old ddr image
    # (not sure this is necessary)
    make -C ${a3700_utils} clean DDR_TOPOLOGY=5

    # path to ARM's Trusted Firmware-A repo
    local tfa=${ROOT_DIR}/trusted-firmware-a

    # delete all build contents and rebuild
    make -C "$tfa" distclean
    make -C "$tfa" \
            PLAT=a3700 \
            USE_COHERENT_MEM=0 \
            MV_DDR_PATH="$ROOT_DIR"/mv-ddr-marvell \
            DDR_TOPOLOGY=5 \
            CLOCKSPRESET=CPU_${cpu_speed}_DDR_${ddr_speed} \
            WTP=${a3700_utils} \
            CRYPTOPP_PATH="$ROOT_DIR"/cryptopp \
            BL33=${u_boot}/u-boot.bin \
            WTMI_IMG=${mbb}/wtmi_app.bin \
            mrvl_flash

    if [ ! -f "$tfa/build/a3700/release/flash-image.bin" ]; then
        echo "Build failed!"
        return 0
    fi

    # package the output
    local build_path
    build_path=${ROOT_DIR}/build/
    mkdir -p "$build_path"

    # copy image to output folder
    cp "$tfa/build/a3700/release/flash-image.bin" "$build_path/$(date +"%Y%m%d-%H%M").bin"
    cp "$tfa/build/a3700/release/flash-image.bin" "$build_path/latest.bin"
    sync

}
