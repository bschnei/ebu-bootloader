This is heavily inspired by the [mox-boot-builder](https://gitlab.nic.cz/turris/mox-boot-builder) project. The Turris MOX shares the same Marvell Armada 3720 chipset as the Globalscale ESPRESSObin Ultra.

These are crude directions for getting a build based on code in Globalscale's repository.

# Build Host

Follow directions here to set up a 64-bit linux build host with the right packages and cross compilers: https://espressobin.net/espressobin-ultra-build-instruction/

I use a VirtualBox host based on Ubuntu 18.04 to stay as close to the factory's instructions as possible at this point. Fully upgrade all packages and install all additional packages as noted at mfg's site.

Note that if you follow the directions on the manufacturer's page and not the directions below you will encounter errors. In particular you want to use the -gti tagged branches across all of the manufacturer's repos and not just some of them.

Download the Linaro cross-compiler and extract it into a directory named `toolchain`:
```
wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz

mkdir toolchain

tar -xvf gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -C toolchain/
```
# Download Repositories

1. `git clone https://github.com/globalscaletechnologies/A3700-utils-marvell.git -b A3700_utils-armada-18.12.0-gti`
1. `git clone https://github.com/globalscaletechnologies/atf-marvell.git -b atf-v1.5-armada-18.12-gti trusted-firmware-a`
1. `git clone https://github.com/globalscaletechnologies/mv-ddr-marvell.git`
1. `git clone https://github.com/globalscaletechnologies/u-boot-marvell.git -b u-boot-2018.03-armada-18.12-gti`

Note that it seems in some cases git is called within the builds for at least two of the above projects. As a result, they need to be git repos and not just pure source code. Source: https://trustedfirmware-a.readthedocs.io/en/latest/plat/marvell/index.html

# Building
`source build.sh`
`gtibuild`

# Flashing
Put the contents of the out/ folder on a USB drive and se the bubt command in u-boot. If your device becomes unstable or won't boot, you'll need to boot a stable image via UART and then use bubt u-boot to flash a stable image. Don't use the WtpDownloader tool from Marvell. It sucks. Use the mox-imager instead.
