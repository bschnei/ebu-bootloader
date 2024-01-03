#!/usr/bin/env bash

ROOT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# cross compile settings for make
export ARCH=arm64
export CROSS_COMPILE=${ROOT_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

# Marvell's default assumption lines up with Ubuntu's package name for the
# 32-bit compiler. Set explicitly or modify as needed.
#export CROSS_CM3=/usr/bin/arm-linux-gnueabi-

function build_bootloader {

    # path to U-Boot source code
    local uboot=${ROOT_DIR}/u-boot-marvell

    make -C "$uboot" distclean

    # build configuration
    make -C "$uboot" gti_ccpe-88f3720_defconfig

    # build u-boot.bin
    make -C "$uboot" DEVICE_TREE=armada-3720-ccpe

    # see README
    local cpu_speed=1000

    # DDR clock speed is a function of cpu_speed
    local ddr_speed=800
    if [ "$cpu_speed" == 1200 ]; then
        ddr_speed=750
    fi

    # path to A3700 git repo (must be a git repo)
    local a3700_utils=${ROOT_DIR}/A3700-utils-marvell

    # path to ARM Trusted Firmware repo
    local atf=${ROOT_DIR}/trusted-firmware-a

    # clean a3700-utils image to prevent using old ddr image
    make -C "$a3700_utils" clean DDR_TOPOLOGY=5

    # clean the source tree and build
    make -C "$atf" distclean
    make -C "$atf" \
            PLAT=a3700 \
            DEBUG=0 \
            USE_COHERENT_MEM=0 \
            MV_DDR_PATH="$ROOT_DIR"/mv-ddr-marvell \
            DDR_TOPOLOGY=5 \
            CLOCKSPRESET=CPU_${cpu_speed}_DDR_${ddr_speed} \
            WTP=${a3700_utils} \
            CRYPTOPP_PATH="$ROOT_DIR"/cryptopp \
            BL33=${uboot}/u-boot.bin \
            mrvl_flash

    if [ ! -f "$atf/build/a3700/release/flash-image.bin" ]; then
        echo "Failed to build FIP!"
        return 0
    fi

    # package the output
    local build_path
    build_path=${ROOT_DIR}/build/
    mkdir -p "$build_path"

    # copy image to output folder
    cp "$atf/build/a3700/release/flash-image.bin" "$build_path/$(date +"%Y%m%d-%H%M").bin"
    cp "$atf/build/a3700/release/flash-image.bin" "$build_path/latest.bin"
    sync

}
