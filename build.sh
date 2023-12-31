#!/bin/bash

ROOT_DIR=$(pwd)

# cross compile settings for make
export ARCH=arm64
export CROSS_COMPILE=${ROOT_DIR}/toolchain/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
#export CROSS_CM3=/usr/bin/arm-linux-gnueabi-

# location of source code
export a3700_utils=${ROOT_DIR}/A3700-utils-marvell
export atf=${ROOT_DIR}/trusted-firmware-a
export uboot=${ROOT_DIR}/u-boot-marvell


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

function build_uboot {

    make -C "$uboot" distclean

    # build configuration
    make -C "$uboot" gti_ccpe-88f3720_defconfig

    # build u-boot.bin
    make -C "$uboot" DEVICE_TREE=armada-3720-ccpe

    return 0
}

# build ARM Trusted Firmware
function build_atf {
    local cpu_speed=$1
    
    # DDR clock speed is a function of cpu_speed
    local ddr_speed=800
    if [ "$cpu_speed" == 1200 ]; then
        ddr_speed=750
    fi

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
            BL33=${uboot}/u-boot.bin \
            all fip

    # NOTE: build target that is only "mrvl_flash" or only "fip" currently fails to boot, so use "all fip"

    return 0
}

function build_bootloader {

    # U-Boot needs to build successfully first since it gets
    # integrated into a single Firmware Image Package (FIP) file as part of
    # building the rest of the ARM Trusted Firmware
    build_uboot

    # see README
    local cpu_speed=1000

    build_atf $cpu_speed

    # package the output
    local build_path
    build_path=${ROOT_DIR}/build/$(date +"%Y%m%d-%H%M")
    mkdir -p "$build_path"

    # get commit ids
    local git_wtp
    git_wtp=$(query_commitid "$a3700_utils")

    local git_atf
    git_atf=$(query_commitid "$atf")

    local git_uboot
    git_uboot=$(query_commitid "$uboot")

    # record build settings
    local infomsg="CPU: ${cpu_speed}\nATF: g${git_atf}\nU-Boot: g${git_uboot}\nA3700 Utils: g${git_wtp}"
    echo -e "$infomsg" > "$build_path"/buildinfo.txt

    # copy image to output folder
    cp "$atf/build/a3700/release/flash-image.bin" "$build_path/flash.bin"
    sync

}
