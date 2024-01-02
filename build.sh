#!/bin/bash

ROOT_DIR=$(pwd)

# cross compile settings for make
export ARCH=arm64
export CROSS_COMPILE=${ROOT_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

# Marvell's default assumption lines up with Ubuntu's package name for the
# 32-bit compiler. Set explicitly or modify as needed.
#export CROSS_CM3=/usr/bin/arm-linux-gnueabi-

# location of source code
export a3700_utils=${ROOT_DIR}/A3700-utils-marvell
export atf=${ROOT_DIR}/trusted-firmware-a
export uboot=${ROOT_DIR}/u-boot-marvell


function build_uboot {

    make -C "$uboot" distclean

    # build configuration
    make -C "$uboot" gti_ccpe-88f3720_defconfig

    # build u-boot.bin
    make -C "$uboot" DEVICE_TREE=armada-3720-ccpe

    return 0
}

function build_bootloader {

    # U-Boot needs to build successfully first since it gets
    # integrated into the final image file
    build_uboot

    # see README
    local cpu_speed=1000

    # DDR clock speed is a function of cpu_speed
    local ddr_speed=800
    if [ "$cpu_speed" == 1200 ]; then
        ddr_speed=750
    fi

    # path to A3700 git repository (must be a git repo)
    local a3700_utils=${ROOT_DIR}/A3700-utils-marvell

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
            all fip mrvl_flash

    # NOTE: in older ATF versions, a build target that is only "mrvl_flash" or only "fip" will fail to boot, so use "all fip"
    # This does not seem to be an issue in newer versions of ATF--"mrvl flash" seems like it should work, but testing is needed.

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
