#!/bin/bash

ROOT_DIR=$(pwd)

# cross compile settings for make
export ARCH=arm64
export CROSS_COMPILE=${ROOT_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

# location of source code
export a3700_utils=${ROOT_DIR}/A3700-utils-marvell
export atf=${ROOT_DIR}/trusted-firmware-a
export uboot=${ROOT_DIR}/u-boot-marvell

# used by ARM Trusted Firmware
export BL33=${uboot}/u-boot.bin
export CROSS_CM3=/usr/bin/arm-linux-gnueabi-
export WTP=${a3700_utils}
export MV_DDR_PATH=${ROOT_DIR}/mv-ddr-marvell

BUILD_DATE=$(date +"%Y%m%d")
export BUILD_DATE
export BUILDOUT=${ROOT_DIR}/out/${BUILD_DATE}

function query_commitid {
    local path=$1

    # query latest commit
    if [ -d "$path/.git" ]; then
        commitid=$(git -C "$path" log --no-merges --pretty=format:"%h%n" -1)
    else
        commitid="0000000"
    fi

    echo "$commitid"
}

function create_dir {
    local dir=$1

    if [ -z "$dir" ]; then
        return
    fi

    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
    fi
}

function build_uboot {

    if [ -f "$uboot/u-boot.bin" ]; then
        # remove old u-boot.bin
        rm "$uboot/u-boot.bin"
    fi

    # update u-boot commit id
    UBOOTGITID=$(query_commitid "$uboot")

    make -C "$uboot" distclean
    if [ -d "$uboot/.git" ]; then
        git -C "$uboot" clean -f
    fi

    make -C "$uboot" gti_ccpe-88f3720_defconfig
    make -C "$uboot" DEVICE_TREE=armada-3720-ccpe

    return 0
}

# build ARM Trusted Firmware
function build_atf {

    # 5 = ESPRESSObin Ultra
    local ddr_topology=5

    # See README
    local cpu_speed=1000

    # DDR clock speed is a function of cpu_speed
    local ddr_speed=800
    if [ $cpu_speed == 1200 ]; then
        ddr_speed=750
    fi

    # clean a3700-utils image to prevent using old ddr image
    make -C "$a3700_utils" clean DDR_TOPOLOGY=${ddr_topology}

    # clean the source tree and build
    make -C "$atf" distclean
    make -C "$atf" DEBUG=0 USE_COHERENT_MEM=0 LOG_LEVEL=20 \
            CLOCKSPRESET=CPU_${cpu_speed}_DDR_${ddr_speed} \
            PLAT=a3700 DDR_TOPOLOGY=${ddr_topology} \
            CRYPTOPP_PATH="${ROOT_DIR}"/cryptopp \
            all fip mrvl_flash

    # get commit ids
    WTPGITID=$(query_commitid "$a3700_utils")
    ATFGITID=$(query_commitid "$atf")

    # record build settings in a separate file
    local infomsg="CPU: ${cpu_speed}\nATF: g${ATFGITID}\nU-Boot: g${UBOOTGITID}\nA3700 Utils: g${WTPGITID}"
    echo -e "$infomsg" > "${BUILDOUT}"/buildinfo.txt
    
    # copy image to output folder
    cp "$atf/build/a3700/release/flash-image.bin" "$BUILDOUT/flash.bin"
    sync

    return 0
}

function build_bootloader {

    create_dir "${BUILDOUT}"

    # U-Boot needs to build successfully first since it gets
    # integrated into a single flash image file as part of
    # building the rest of the ARM Trusted Firmware
    build_uboot

    if [ ! -f "${BL33}" ]; then
        echo "Failed to build u-boot!"
        return 0
    fi

    build_atf

}
