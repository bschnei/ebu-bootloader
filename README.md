# ESPRESSObin Ultra Bootloader Builder

This is inspired by the [mox-boot-builder](https://gitlab.nic.cz/turris/mox-boot-builder) project. The Turris MOX shares the same Marvell Armada 3720 SoC as the [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/).

These are crude directions for building based on code in [Globalscale's repositories](https://github.com/globalscaletechnologies).

## Build Host

The directions here are for a fully upgraded Ubuntu Server 20.04 virtual machine using a base image from [osboxes.org](https://www.osboxes.org/ubuntu-server/#ubuntu-server-20-04-4-vbox).

Make sure all build dependencies are installed:
```
sudo apt install make binutils build-essential gcc g++ \
bash patch gzip bzip2 perl tar cpio zlib1g-dev \
gawk ccache gettext libssl-dev libncurses5 minicom git \
bison flex device-tree-compiler gcc-arm-linux-gnueabi
```

Note: `gcc-arm-linux-gnueabi` provides a 32-bit ARM cross-compiler which is used to compile part of the firmware meant to run on an internal Cortex-M3 coprocessor.

Download a 64-bit ARM (aarch64) cross-compiler and extract it into a directory named `toolchain`:
```
wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
mkdir toolchain
tar -xvf gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -C toolchain/
```
## Download Repositories

__IMPORTANT:__ if you follow the build directions on the [manufacturer's page](https://espressobin.net/espressobin-ultra-build-instruction/) and not the directions below you will encounter errors. In particular you want to use the `-gti` suffixed branches across all of the manufacturer's repos and not just some of them.

```
git clone https://github.com/globalscaletechnologies/A3700-utils-marvell.git -b A3700_utils-armada-18.12.0-gti
git clone https://github.com/globalscaletechnologies/atf-marvell.git -b atf-v1.5-armada-18.12-gti trusted-firmware-a
git clone https://github.com/globalscaletechnologies/mv-ddr-marvell.git
git clone https://github.com/globalscaletechnologies/u-boot-marvell.git -b u-boot-2018.03-armada-18.12-gti
```
Note that it seems in some cases git is called within the builds for at least two of the above projects. As a result, they need to be git repos and not just pure source code. Source: https://trustedfirmware-a.readthedocs.io/en/latest/plat/marvell/index.html

## Patching U-Boot
U-Boot will fail to compile on newer GCC compilers unless patched. See [here](https://github.com/BPI-SINOVOIP/BPI-M4-bsp/issues/4#issuecomment-1296184876) for a fix.

## Building
```
source build.sh
gtibuild
```
# Flashing
Put the .bin file from the out/ folder you want to flash onto a USB flash drive and use the `bubt` command in u-boot to flash. If your device can't make it to the u-boot prompt, you'll need to boot a stable image via UART and then use bubt u-boot to flash a stable image. Don't use the WtpDownloader tool from Marvell. It sucks. Use the [mox-imager](https://gitlab.nic.cz/turris/mox-imager) instead.

