# ESPRESSObin Ultra Bootloader

The [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/) is a network appliance built upon Marvell's Armada 3720 SoC (A3700). The source for its firmware is open, but Globalscale's [build instructions](https://espressobin.net/espressobin-ultra-build-instruction/) and [forks](https://github.com/globalscaletechnologies) have not been kept up-to-date.

Using OEM firmware, the hardware random number generator is unavailable and CPU frequency scaling is limited to a maximum of 1Ghz instead of the 1.2GHz it's supposed to be capable of supporting.

An excellent and detailed explanation of the build process this project follows can be found [here](https://trustedfirmware-a.readthedocs.io/en/v2.10/plat/marvell/armada/build.html).

Major changes:

* Upgrade build host from Ubuntu 18.04 to 20.04 (22.04 has not been tested, but was unstable with earlier builds)
* Move all source code away from old forks to upstream projects
* Upgrade source projects to latest stable version tag (or apparent equivalent)
* Add required device tree to u-boot and configure

## Build Host

The directions here are for a fully upgraded Ubuntu Server 20.04 virtual machine using a base image from [osboxes.org](https://www.osboxes.org/ubuntu-server/#ubuntu-server-20-04-4-vbox). Upgrade all packages, resolve any issues, and restart the VM which should leave you with Ubuntu 20.04.6.

__Note__: AFAIK the build process for osboxes images is not open source. If that's a problem in your scenario, install Ubuntu Server 20.04 from scratch. It's also not required to use Ubuntu--any Linux distro should work provided the required build dependencies are satisfied and the _same version_ is used as that in Ubuntu 20.04.6.

Make sure all build dependencies are installed:
```
sudo apt install build-essential binutils \
bash patch gzip bzip2 perl tar cpio zlib1g-dev \
gawk ccache gettext libssl-dev libncurses5 minicom git \
bison flex device-tree-compiler gcc-arm-linux-gnueabi
```
Many of these are likely already installed in Ubuntu, but this is based on Globalscale's guide. It would be nice to specify exact packages and versions at some point so that any properly set up Linux distribution can run the build script.

Note: While the Armada 3720 uses 64-bit ARMv8 processors, `gcc-arm-linux-gnueabi` provides a 32-bit ARM cross-compiler which is used to compile a part of the firmware meant to run on an internal Cortex-M3 coprocessor.

The 64-bit ARM (aarch64) cross-compiler we get from Linaro per Globalscale. We extract it into a directory named `toolchain`:
```
wget https://releases.linaro.org/components/toolchain/binaries/7.3-2018.05/aarch64-linux-gnu/gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz
mkdir toolchain
tar -xvf gcc-linaro-7.3.1-2018.05-x86_64_aarch64-linux-gnu.tar.xz -C toolchain/
```
This toolchain is fairly old and likely a limiting factor in the ability to upgrade the build host OS.

## mv-ddr-marvell notes
The mv-ddr-marvell repo is used by the A3700-utils-marvell repo to make the `a3700_tool` target which is an executable. The executable gets copied (and renamed) to `A3700-utils-marvell/tim/ddr/ddr_tool` before being run by `A3700-utils-marvell/scripts/buildtim.sh`. The program generates the `ddr_static.txt` file in `A3700-utils-marvell/tim/ddr`. The contents of the file then get inserted by the `buildtim.sh` script into the `atf-ntim.txt` file used by ATF-A to build the firmware image. The `ddr_static.txt` file contains instructions used to initialize memory.

Globalscale's repos produce a `ddr_static.txt` file that differs from Marvell's in two places. The first difference seems to concern [setting the DDR PHY drive strength](https://github.com/globalscaletechnologies/A3700-utils-marvell/commit/feced21c4c343428eab2f99cc9c78028bb961690) and is __critical__ for system stability. The [second difference](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/commit/4208ad5f2d1cee6125d3047ea1aac90a051e3d16) doesn't seem to impact system stability.

The mv-ddr-marvell submodule in this repo uses [my fork](https://github.com/bschnei/mv-ddr-marvell) of the repository which patches the first difference, but not the second which seems to be a good fix.

## Building
To build the required ATF image used by [bubt](https://source.denx.de/u-boot/u-boot/-/blob/master/doc/mvebu/cmd/bubt.txt) to update the device's firmware:
```
make clean
make
```
The image is output to `trusted-firmware-a/build/a3700/release/flash-image.bin`.

## USB Flashing
Put the ATF image file onto a USB flash drive and use the `bubt` command from u-boot to flash. If your device can't make it to the u-boot prompt using the firmware stored on the device (in SPINOR), you'll need to sideload a known stable ATF image via UART using [mox-imager](https://gitlab.nic.cz/turris/mox-imager).

Example: `mox-imager -D /dev/ttyUSB0 -b 3000000 -E flash-image.bin`

Where `flash-image.bin` is the path to the image you want to sideload. Note that the device needs to be put in UART boot mode via changing a jumper on the board itself (see the Quick Start Guide in docs). It may take a few tries for `mox-imager` to put the device in download mode. Be sure to close any other programs using /dev/ttyUSB0 like Putty. Once u-boot loads `bubt` is then available to flash the device again. After flashing a known working image to SPI, power down the device and change the jumper back to confirm the device boots as expected.

## Known Issues

### CPU Frequency Scaling at 1.2GHz
The Armada 3720 CPU (88F3720) is supposedly capable of speeds up to 1.2Ghz, but [Linux disables 1.2Ghz](https://github.com/torvalds/linux/commit/484f2b7c61b9ae58cc00c5127bcbcd9177af8dfe) as a speed for this device. If you flash a bootloader that sets the CPU speed to 1.2Ghz (CLOCKSPRESET=CPU_1200_DDR_750) Linux will not be able to manage the CPU frequency (cpufreq-dt does not load) and the system will run stably, but at full speed (1.2Ghz) continuously.

A significant contributor to both kernel and A3700 firmware development believes the firmware is the source of the problem. For a long discussion, see [here](https://github.com/MarvellEmbeddedProcessors/linux-marvell/issues/20).

For CPU frequency scaling to work, the firmware should set the CPU clock to 1GHz (CLOCKSPRESET=CPU_1000_DDR_800).

### DDR Initialization Speed
DDR initialization is considerably slower in Marvell's A3700-utils-repo than in Globalscale's. This is related to five consecutive commits whose message is tagged with ddr_init that were committed May 21, 2019 between versions 18.2.0 and 18.2.1, the first of which is [here](https://github.com/MarvellEmbeddedProcessors/A3700-utils-marvell/commit/4d785e3ec35daf77d85c0f26e91388afcca0d478). Using copies of the `sys_init/ddr` files prior to those changes resolves the issue but would lose also lose any improvements/fixes.
