# ESPRESSObin Ultra Bootloader

The [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/) is a network appliance built with Marvell's Armada 3720 SoC (A3700). The source for its bootloader is open, but Globalscale's [build instructions](https://espressobin.net/espressobin-ultra-build-instruction/) and [forks](https://github.com/globalscaletechnologies) have not been kept up-to-date.

There are also a variety of known issues with the factory bootloader:
* CPU frequency scaling when the bootloader sets the frequency to 1.2Ghz is [disabled](https://github.com/torvalds/linux/commit/484f2b7c61b9ae58cc00c5127bcbcd9177af8dfe).
* EFI booting from U-Boot is [broken](https://lore.kernel.org/regressions/NpVfaMj--3-9@bens.haus/T/).
* The hardware random number generator contained in the Cortex-M3 coprocessor is [not available](https://gitlab.nic.cz/turris/mox-boot-builder).

This project seeks to address these and other issues associated with old/unmaintained source code. 

## Build Host

The directions, makefile, and script here are meant to be run on a fully upgraded Ubuntu Server 22.04 virtual machine using a base image from [osboxes.org](https://www.osboxes.org/ubuntu-server/#ubuntu-server-22-04-vbox). Upgrade all packages, resolve any issues, and restart the VM which should leave you with Ubuntu 22.04.4.

__Note__: AFAIK the build process for osboxes images is not open source. If that's a problem in your scenario, install Ubuntu Server 22.04 from scratch. It's also not required to use Ubuntu--any Linux distro should work provided the required build dependencies are satisfied and the _same version_ is used as that in Ubuntu 22.04.4.

Install build dependencies:
```
sudo apt install bison flex g++ gcc \
gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
libncurses-dev libssl-dev make
```

Note: While the Armada 3720 uses 64-bit ARMv8 processors, `gcc-arm-linux-gnueabi` provides a 32-bit ARM cross-compiler which is used to compile a part of the bootloader (`wtmi_app.bin`) meant to run on an internal Cortex-M3 coprocessor.

## Building
A detailed explanation of the build process this project follows can be found [here](https://trustedfirmware-a.readthedocs.io/en/v2.10/plat/marvell/armada/build.html). Note that this project uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) which need to be initialized and updated prior to building.

To build the required TF-A image used by [bubt](https://source.denx.de/u-boot/u-boot/-/blob/master/doc/mvebu/cmd/bubt.txt) to update the device's bootloader, run:
```
make clean
make
```
When successful, the image meant for `bubt` is output to `trusted-firmware-a/build/a3700/release/flash-image.bin`.

## USB Flashing
Put the TF-A image file onto a USB flash drive and run `bubt flash-image.bin spi usb` to flash the image to the device's permanent storage (SPINOR). Resetting the device will then cause it to load the newly flashed image.

## UART Recovery
If the device fails to make it to the U-Boot prompt using the bootloader stored in SPI, it is possible to sideload a known stable TF-A image via UART using [mox-imager](https://gitlab.nic.cz/turris/mox-imager).

For example: `mox-imager -D /dev/ttyUSB0 -b 3000000 -E flash-image.bin` where `flash-image.bin` is the path to the image you want to sideload.

Note that the device might need to be put in UART boot mode by setting jumper switch J10 to 0 on the board itself. Normal boot mode has all jumpers in the block (J3, J10, and J11) set to 1 so normally only J10 might need to be changed. For more info, see page 13 in the Quick Start Guide in docs.

It may take a few power cycles for `mox-imager` to successfully put the device in download mode. Be sure to close any other programs that could interfere with the device file that represents the USB console (usually /dev/ttyUSB0) such as PuTTY. Once U-Boot loads, `bubt` is then available to flash SPI again. After flashing a known working image to SPI, power down the device, change jumper J10 back if needed, and confirm the device boots as expected.

## Notes

### U-Boot
Upstream U-Boot is missing the device tree (.dts) and default configuration (defconfig) for the ESPRESSObin Ultra. A [patch for the device tree](https://patchwork.ozlabs.org/project/uboot/list/?series=397560) has been submitted upstream. The default configuration is patched in as mvebu_espressobin_ultra-88f3720_defconfig.

### CPU Frequency Scaling at 1.2GHz
The Armada 3720 CPU (88F3720) is capable of speeds up to 1.2Ghz, but mainstream Linux disables 1.2Ghz as a speed for this device. If you flash a bootloader that sets the CPU speed to 1.2Ghz (CLOCKSPRESET=CPU_1200_DDR_750) Linux will not be able to manage the CPU frequency (cpufreq-dt does not load) and the system will run stably, but at full speed (1.2Ghz) continuously. For a long discussion, see [here](https://github.com/MarvellEmbeddedProcessors/linux-marvell/issues/20).

This project adjusts the value for the Channel 0 PHY Control 2 in the mv-ddr-marvell repo to that used in [Globalscale's repo](https://github.com/globalscaletechnologies/A3700-utils-marvell/commit/feced21c4c343428eab2f99cc9c78028bb961690) which results in a stable system at all supported CPU frequencies. A [PR](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/pull/44) has been opened upstream.

The Linux kernel needs to be patched to enable frequency scaling when the bootloader sets the CPU speed to 1.2Ghz. A script to patch and package the kernel for Arch Linux can be found [here](https://github.com/bschnei/linux-ebu/). Alternatively, frequency scaling will work without patching the kernel if the bootloader sets the CPU clock to 1GHz (`make CLOCKSPRESET=CPU_1000_DDR_800`), but that will be the maximum available frequency to the operating system.

### Marvell repos
The mv-ddr repo is used by the A3700-utils repo to make the `a3700_tool` target which is an executable. The executable gets copied (and renamed) to `A3700-utils-marvell/tim/ddr/ddr_tool` before being run by `A3700-utils-marvell/scripts/buildtim.sh`. The program generates the `ddr_static.txt` file in `A3700-utils-marvell/tim/ddr`. The contents of the file then get inserted by the `buildtim.sh` script into the `atf-ntim.txt` file used by TF-A to build the firmware image. The `ddr_static.txt` file contains instructions used to initialize memory.

Globalscale's repos produce a `ddr_static.txt` file that differs from Marvell's in two places. The first difference is noted above. The [second difference](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/commit/4208ad5f2d1cee6125d3047ea1aac90a051e3d16) doesn't seem to impact system stability so we use Marvell's version.