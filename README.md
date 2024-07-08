# ESPRESSObin Ultra Bootloader

The [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/) is a network appliance built with Marvell's Armada 3720 SoC (A3700). The source for its bootloader is open, but Globalscale's [build instructions](https://espressobin.net/espressobin-ultra-build-instruction/) and [forks](https://github.com/globalscaletechnologies) have not been kept up-to-date.

There are also a variety of known issues with the factory bootloader:
* CPU frequency scaling when the bootloader sets the frequency to 1.2Ghz is [disabled](https://github.com/torvalds/linux/commit/484f2b7c61b9ae58cc00c5127bcbcd9177af8dfe).
* EFI booting from U-Boot is [broken](https://lore.kernel.org/regressions/NpVfaMj--3-9@bens.haus/T/).
* The hardware random number generator contained in the Cortex-M3 coprocessor is [not available](https://gitlab.nic.cz/turris/mox-boot-builder).

This project seeks to address these and other issues associated with old/unmaintained source code. 

## Build Host

Any x64 Linux host should work provided the required build dependencies are installed. Building will fail with a pretty obvious error message if a required dependency is missing. For Ubuntu Server (and relatives), the additional dependencies (i.e. those not included in a base 22.04 image) can be installed with:
```
sudo apt install bison flex g++ gcc \
gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi \
libncurses-dev libssl-dev make
```

For Arch Linux, the `base-devel` meta package, `bc`, and the cross-compilers `arm-linux-gnueabi-gcc` and `aarch64-linux-gnu-gcc` should be all that's needed.

While the Armada 3720 uses 64-bit ARMv8 processors, `arm-linux-gnueabi` is the 32-bit ARM cross-compiler which is used to compile a part of the bootloader (`wtmi_app.bin`) meant to run on an internal Cortex-M3 coprocessor.

I'm currently building with GCC 14.1, but older compiler versions should work OK. I strongly recommend using the same version of GCC for all three architectures (x64, arm, aarch64). Inconsistent compiler versions could lead to a build that appears to complete just fine but won't actually boot.

## Building
A detailed explanation of the build process this project follows can be found [here](https://trustedfirmware-a.readthedocs.io/en/latest/plat/marvell/armada/build.html). Note that this project uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) which need to be initialized and updated prior to building.

To build the required [Trusted Firmware-A](https://www.trustedfirmware.org/projects/tf-a) (TF-A) image used by [bubt](https://source.denx.de/u-boot/u-boot/-/blob/master/doc/mvebu/cmd/bubt.txt) to update the device's bootloader, run:
```
make clean
make
```
When successful, the image meant for `bubt` is output to `trusted-firmware-a/build/a3700/release/flash-image.bin`.

## Testing
The [mox-imager](https://gitlab.nic.cz/turris/mox-imager) tool makes it possible to boot the device from a TF-A image *without flashing the new image to the device's permanent storage* (SPINOR). I'll refer to this process as *sideloading*.

Sideloading facilitates testing a potential new bootloader image without permanently updating the device's stored bootloader. For example, if you sideload a potential new TF-A image via mox-imager and discover that it's so broken you cannot boot Linux, you can simply power cycle the device to boot from the bootloader stored to SPINOR.

**Note:** successfully booting Linux is not a guarantee that a new image is also *stable* and *fully functional*. Because use cases vary (e.g. I don't use the Bluetooth/WiFi device), only you can decide whether or not you are comfortable permanently updating the bootloader.

For my use case, I check boot messages and systemd logs to make sure there aren't any unexpected/new messages. I then typically use the new image for about a week before flashing to a production device used as home edge router. I put the CPU and memory under load by compiling source and/or running [stress](https://github.com/resurrecting-open-source-projects/stress). I also spot check device features I knew to be working if upstream has changes to device trees, e.g.

To use mox-imager, connect the USB serial console port to the host that will run mox-imager and has the TF-A image you want to sideload. Linux should create a device node like /dev/ttyUSB0. Be sure to close any other programs that could interfere with the device node that represents the USB console such as PuTTY. A sample command might be: `mox-imager -D /dev/ttyUSB0 -b 3000000 -t -E flash-image.bin` where `flash-image.bin` is the path to the image you want to sideload.

Follow the on-screen instructions. It is normal for mox-imager to need several power cycles before successfully putting the device in sideload mode.

## Flashing to Permanent Storage
After you are comfortable with the stability and performance observed in testing, put the TF-A image file onto a USB flash drive and plug it into the device. Power cycle and stop the boot process at U-Boot. Run `bubt flash-image.bin spi usb` to flash the image to the device's permanent storage. Resetting the device will then cause it to load the newly flashed image.

## Recovery
Sideloading can also be used to recover from a bad bootloader flashed to permanent storage (e.g. power goes out while flashing, bit flips, etc.), but you have to have a known stable bootloader handy. I use the `archive.sh` script and mount the build directory directly to a USB thumb drive I use exclusively for storing builds. To recover: sideload your known working good image, interrupt U-Boot, and then use `bubt` to flash the good bootloader to SPI.

## Notes

### U-Boot
Support for the ESPRESSObin Ultra has been [merged](https://source.denx.de/u-boot/custodians/u-boot-marvell/-/commit/d901c9b8d69e2036c3e991e0364b5eb008788a32) into the Marvell ARM Custodian Tree. This should make it part of the 2024.10 release of U-Boot. Until then, configuration (mvebu_espressobin_ultra-88f3720_defconfig) is copied into `u-boot/configs` and the device tree (u-boot-dts.patch) is patched in.

### CPU Frequency Scaling at 1.2GHz
The Armada 3720 CPU (88F3720) is capable of speeds up to 1.2Ghz, but [mainstream Linux disables 1.2Ghz](https://github.com/torvalds/linux/blob/master/drivers/cpufreq/armada-37xx-cpufreq.c#L109) as a speed for this device. If you flash a bootloader that sets the CPU speed to 1.2Ghz (CLOCKSPRESET=CPU_1200_DDR_750) Linux will not be able to manage the CPU frequency (cpufreq-dt does not load) and the system will run stably, but at full speed (1.2Ghz) continuously. For a long discussion, see [here](https://github.com/MarvellEmbeddedProcessors/linux-marvell/issues/20).

The Linux kernel needs to be patched to enable frequency scaling when the bootloader sets the CPU speed to 1.2Ghz. A script to patch and package the kernel for Arch Linux can be found [here](https://github.com/bschnei/linux-a3700/).

Alternatively, frequency scaling will work without patching the kernel if the bootloader sets the CPU clock to 1GHz (`make CLOCKSPRESET=CPU_1000_DDR_800`), but that will be the maximum available frequency to the operating system.

### Marvell repos
The mv-ddr repo is used by the A3700-utils repo to make the `a3700_tool` target which is an executable. The executable gets copied (and renamed) to `A3700-utils-marvell/tim/ddr/ddr_tool` before being run by `A3700-utils-marvell/scripts/buildtim.sh`. The program generates the `ddr_static.txt` file in `A3700-utils-marvell/tim/ddr`. The contents of the file then get inserted by the `buildtim.sh` script into the `atf-ntim.txt` file used by TF-A to build the firmware image. The `ddr_static.txt` file contains instructions used to initialize memory.

Globalscale's repos produce a `ddr_static.txt` file that differs from Marvell's in [one place](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/commit/4208ad5f2d1cee6125d3047ea1aac90a051e3d16). However, Marvell's version is what is currently known to be stable so that is what is used.