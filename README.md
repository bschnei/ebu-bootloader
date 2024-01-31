# ESPRESSObin Ultra Bootloader

The [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/) is a network appliance built with Marvell's Armada 3720 SoC (A3700). The source for its firmware is open, but Globalscale's [build instructions](https://espressobin.net/espressobin-ultra-build-instruction/) and [forks](https://github.com/globalscaletechnologies) have not been kept up-to-date.

The device (as I received it from Globalscale) had the CPU frequency limited to a maximum of 800Mhz instead of the 1.2GHz advertised. The hardware random number generator contained in the Cortex-M3 coprocessor is also not available to the operating system.

Major changes:

* Upgrade build host from Ubuntu 18.04 to 20.04 (22.04 has not been tested, but was unstable with earlier builds)
* Move all source code away from old forks to upstream projects
* Upgrade source projects to latest stable version tag (or apparent equivalent)
* Use WTMI application from [mox-boot-builder](https://gitlab.nic.cz/turris/mox-boot-builder) project which exposes hardware RNG to the OS
* Add device tree and config for this device to U-Boot

## Build Host

The directions, makefile, and script here are meant to be run on a fully upgraded Ubuntu Server 20.04 virtual machine using a base image from [osboxes.org](https://www.osboxes.org/ubuntu-server/#ubuntu-server-20-04-4-vbox). Upgrade all packages, resolve any issues, and restart the VM which should leave you with Ubuntu 20.04.6.

__Note__: AFAIK the build process for osboxes images is not open source. If that's a problem in your scenario, install Ubuntu Server 20.04 from scratch. It's also not required to use Ubuntu--any Linux distro should work provided the required build dependencies are satisfied and the _same version_ is used as that in Ubuntu 20.04.6.

Make sure all build dependencies are installed:
```
sudo apt install build-essential binutils \
bash patch gzip bzip2 perl tar cpio zlib1g-dev \
gawk ccache gettext libssl-dev libncurses5 minicom git \
bison flex device-tree-compiler gcc-arm-linux-gnueabi gcc-aarch64-linux-gnu
```
The list above is based on Globalscale's guide, but some of these are already installed in Ubuntu Server. It seems the specific packages that need to be installed for building on Ubuntu are actually:

```
bison
flex
g++
gcc
gcc-aarch64-linux-gnu
gcc-arm-linux-gnueabi
libncurses-dev
libssl-dev
make
```

Note: While the Armada 3720 uses 64-bit ARMv8 processors, `gcc-arm-linux-gnueabi` provides a 32-bit ARM cross-compiler which is used to compile a part of the firmware meant to run on an internal Cortex-M3 coprocessor.

## Building
A detailed explanation of the build process this project follows can be found [here](https://trustedfirmware-a.readthedocs.io/en/v2.10/plat/marvell/armada/build.html). To build the required ATF image used by [bubt](https://source.denx.de/u-boot/u-boot/-/blob/master/doc/mvebu/cmd/bubt.txt) to update the device's firmware:
```
make clean
make
```
The image is output to `trusted-firmware-a/build/a3700/release/flash-image.bin`.

## USB Flashing
Put the ATF image file onto a USB flash drive and run `bubt flash-image.bin spi usb` to flash the image to the device's firmware storage (SPINOR). Resetting the device will then cause it to load the newly flashed firmware image.

## UART Recovery
If your device can't make it to the U-Boot prompt using the firmware stored on the device, you'll need to sideload a known stable ATF image via UART using [mox-imager](https://gitlab.nic.cz/turris/mox-imager).

For example: `mox-imager -D /dev/ttyUSB0 -b 3000000 -E flash-image.bin` where `flash-image.bin` is the path to the image you want to sideload.

Note that the device might need to be put in UART boot mode by setting jumper switch J10 to 0 on the board itself. Normal boot mode has all jumpers in the block (J3, J10, and J11) set to 1 so normally only J10 might need to be changed. For more info, see page 13 in the Quick Start Guide in docs.

It may take a few power cycles for `mox-imager` to successfully put the device in download mode. Be sure to close any other programs that could interfere with the device file that represents the USB console (usually /dev/ttyUSB0) such as PuTTY. Once U-Boot loads, `bubt` is then available to flash the device again. After flashing a known working image to SPI, power down the device, change jumper J10 back if needed, and confirm the device boots as expected.

## Known Issues

### CPU Frequency Scaling at 1.2GHz
The Armada 3720 CPU (88F3720) is capable of speeds up to 1.2Ghz, but mainstream Linux [disables 1.2Ghz](https://github.com/torvalds/linux/commit/484f2b7c61b9ae58cc00c5127bcbcd9177af8dfe) as a speed for this device. If you flash a bootloader that sets the CPU speed to 1.2Ghz (CLOCKSPRESET=CPU_1200_DDR_750) Linux will not be able to manage the CPU frequency (cpufreq-dt does not load) and the system will run stably, but at full speed (1.2Ghz) continuously.

A significant contributor to both kernel and A3700 firmware development believes the firmware is the source of the problem. For a long discussion, see [here](https://github.com/MarvellEmbeddedProcessors/linux-marvell/issues/20). Early testing suggests that stability issues associated with frequency scaling and/or 1.2Ghz clock speeds may be fixed by [using the value set in Globalscale's repos for the Channel 0 PHY Control 2](https://github.com/globalscaletechnologies/A3700-utils-marvell/commit/feced21c4c343428eab2f99cc9c78028bb961690). See Notes below.

A [patched kernel](https://github.com/bschnei/linux-ebu/blob/cpufreq/cpufreq.patch) needs to be built to enable frequency scaling when the firmware sets the CPU frequency to 1.2Ghz. Alternatively, the firmware can set the CPU clock to 1GHz (CLOCKSPRESET=CPU_1000_DDR_800), but that will be the maximum available frequency to the operating system.

### DDR Initialization Speed
DDR initialization is considerably slower in Marvell's A3700-utils-repo than in Globalscale's. This is related to five consecutive commits whose message is tagged with ddr_init that were committed May 21, 2019 between versions 18.2.0 and 18.2.1, the first of which is [here](https://github.com/MarvellEmbeddedProcessors/A3700-utils-marvell/commit/4d785e3ec35daf77d85c0f26e91388afcca0d478). Using copies of the `sys_init/ddr` files prior to those changes resolves the issue but would lose also lose any improvements/fixes. Note that these changes may also be relevant to the CPU frequency scaling issue above. It is __not__ recommended to revert to the older versions of these files. 

## Notes
The mv-ddr repo is used by the A3700-utils repo to make the `a3700_tool` target which is an executable. The executable gets copied (and renamed) to `A3700-utils-marvell/tim/ddr/ddr_tool` before being run by `A3700-utils-marvell/scripts/buildtim.sh`. The program generates the `ddr_static.txt` file in `A3700-utils-marvell/tim/ddr`. The contents of the file then get inserted by the `buildtim.sh` script into the `atf-ntim.txt` file used by TF-A to build the firmware image. The `ddr_static.txt` file contains instructions used to initialize memory.

Globalscale's repos produce a `ddr_static.txt` file that differs from Marvell's in two places. The first difference seems to concern [setting the DDR PHY drive strength](https://github.com/globalscaletechnologies/A3700-utils-marvell/commit/feced21c4c343428eab2f99cc9c78028bb961690) and appears to be important for system stability when using Globalscale's fork of A3700-utils. The [second difference](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/commit/4208ad5f2d1cee6125d3047ea1aac90a051e3d16) doesn't seem to impact system stability.

The mv-ddr-marvell submodule in this repo uses [my fork](https://github.com/bschnei/mv-ddr-marvell) of the repository which patches the first difference, but not the second. Based on early testing, this seems necessary for stability when using more recent versions of A3700-utils.