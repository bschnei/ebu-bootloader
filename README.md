# ESPRESSObin Ultra Bootloader

The [Globalscale ESPRESSObin Ultra](https://globalscaletechnologies.com/product/espressobin-ultra/) is a network appliance built with Marvell's Armada 3720 SoC (A3720). The A3700 product line is part of the Marvell EBU platform (mvebu). The source for its firmware bootloader is open, but Globalscale does not maintain their source. [Their repositories](https://github.com/globalscaletechnologies) are forks of old versions of U-Boot, [ARM Trusted Firmware-A](https://www.trustedfirmware.org/projects/tf-a) (TF-A), and Marvell repositories. Their [build instructions](https://espressobin.net/espressobin-ultra-build-instruction/) also reference outdated build tools.

I also found the following issues with the devices I received from Globalscale in 2023:
* The CPU was underclocked. The maximum advertised frequency is 1.2GHz, but the factory bootloader set the clock speed to 800MHz. See Notes section below.
* [UEFI on U-Boot](https://docs.u-boot.org/en/latest/develop/uefi/uefi.html) was [broken](https://lore.kernel.org/regressions/NpVfaMj--3-9@bens.haus/T/).
* The hardware random number generator contained in the Cortex-M3 coprocessor was [not available to the OS](https://gitlab.nic.cz/turris/mox-boot-builder).

These issues are fixed in this project's releases. Releases are specifically for the ESPRESSObin Ultra, but the Makefile can be adjusted to build bootloaders for other A3700 devices.

## Serial console
The ESPRESSObin Ultra provides a convenient serial console via its Micro-USB port. This console is the only way to update the bootloader and troubleshoot issues that occur early in the boot process (i.e. before the kernel takes over management of the serial console). As a result, setting up console access and becoming familiar with your terminal emulator of choice are prerequisites to updating the bootloader.

Access the console by connecting the Micro-USB port to another computer's USB port. When the other computer is a Linux host, a USB device node (e.g. `/dev/ttyUSB0`) should appear automatically. This device node can then be opened with a terminal emulator with support for serial consoles (e.g. [PuTTY](https://www.putty.org/) or [screen](https://www.gnu.org/software/screen/)).

My preferred tool for connecting to the serial console is [mox-imager](https://gitlab.nic.cz/turris/mox-imager). The source for this tool is available in the `mox-boot-builder` repository which is included in this repository as a submodule. After initializing submodules, the tool can be compiled by running `make` with the mox-imager directory as your working directory. `./mox-imager -D /dev/ttyUSB0 -t` will connect to the device inside whatever terminal you are already using.

## Testing via UART
The `mox-imager` tool also allows us to upload a firmware image over UART (i.e. the same USB connection used by the serial console). This means we can test a potential new image file by uploading it to the device and attempting to boot it directly; we do not need to overwrite a known working image in the device's permanent storage (SPINOR) in order to test it.

For example, if you upload a potential new TF-A image via mox-imager and discover that it's so broken you cannot boot Linux, you can simply power cycle the device and it will go back to booting as it normally would from the bootloader stored to SPINOR.

**Note:** successfully booting Linux is not a guarantee that a new image is also *stable* and *fully functional*. Because use cases vary (e.g. I don't use the Bluetooth/WiFi device), only you can decide whether or not you are comfortable flashing an image to permanent storage.

For my use case, I check boot messages and systemd logs to make sure there aren't any unexpected/new messages. I then typically use the new image for about a week before flashing to a production device used as home edge router. I put the CPU and memory under load by compiling source and/or running [stress](https://github.com/resurrecting-open-source-projects/stress). I also spot check device features I knew to be working if upstream has changes to device trees, for example.

To use `mox-imager`, connect the USB serial console port to the Linux host that will run the program and has the TF-A image you want to upload. Be sure to close any other programs that could interfere with the device node that represents the USB console such as PuTTY. A sample command might be: `mox-imager -D /dev/ttyUSB0 -b 3000000 -t -E flash-image.bin` where `flash-image.bin` is the path to the image you want to sideload.

Follow the on-screen instructions. It is normal for `mox-imager` to need several power cycles before successfully putting the device in UART upload mode.

## Flashing to Permanent Storage
The [bubt](https://source.denx.de/u-boot/u-boot/-/blob/master/doc/mvebu/cmd/bubt.txt) utility is used to flash a bootloader image to permanent storage. After you are comfortable with the stability and performance observed in testing, put the TF-A image file onto a USB flash drive and plug it into the device. Power cycle and interrupt the boot process at U-Boot. Run `bubt flash-image.bin spi usb` to flash the image to the device's permanent storage. Resetting the device will then cause it to load the newly flashed image.

## Recovery
UART uploading via `mox-imager` can also be used to recover from a bad bootloader flashed to permanent storage (e.g. power goes out while flashing, bit flips, etc.), but you have to have a known working/stable bootloader handy. To recover: upload your known working good image with `mox-imager`, interrupt booting at U-Boot, and then use `bubt` to flash the good bootloader to permanent storage as described above.

## Notes

### Building
General documentation for building firmware bootloaders for Marvell hardware can be found [here](https://trustedfirmware-a.readthedocs.io/en/stable/plat/marvell/armada/build.html).

This project uses GitHub Actions to build and release bootloader images so the build process is transparent and replicable. The steps for building are contained in the `.github/workflows` files and can be used to replicate the build process on any x64 Linux host.

The most common reason for building to fail is the absence of a required build dependency. For Arch Linux, the `base-devel` meta package, `bc`, and the cross-compilers `arm-linux-gnueabi-gcc` and `aarch64-linux-gnu-gcc` should be all that's needed. When managing build dependencies manually, I strongly recommend using the same version of GCC for all three architectures (x64, arm, aarch64). Inconsistent compiler versions could lead to a build that appears to complete just fine but won't actually boot.

While the Armada 3720 uses 64-bit ARMv8 processors, `arm-linux-gnueabi` is the 32-bit ARM cross-compiler which is used to compile a part of the bootloader (`wtmi_app.bin`) meant to run on an internal Cortex-M3 coprocessor.

Note that this project uses [git submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) which need to be initialized and updated prior to building.

When successful, the image meant to be used with `bubt` is output to `trusted-firmware-a/build/a3700/release/flash-image.bin`.

### CPU Frequency Scaling at 1.2GHz
The Armada 3720 CPU (88F3720) is capable of speeds up to 1.2Ghz, but my devices arrived underclocked by the factory bootloader. When I used a bootloader built with `CLOCKSPRESET=CPU_1200_DDR_750`, Linux was unable to manage the CPU frequency (the kernel module `cpufreq-dt` will not load), and the system would run stably but at full speed (1.2Ghz) *continuously*. This is because support for frequency scaling when the bootloader sets the frequency to 1.2Ghz was [disabled in the kernel](https://github.com/torvalds/linux/commit/484f2b7c61b9ae58cc00c5127bcbcd9177af8dfe).

This chipset has a long and complicated [history](https://github.com/MarvellEmbeddedProcessors/linux-marvell/issues/20) of instability. It seems likely that at least some (if not all) of the reported instability may have been actually the result of a bad value in Marvell's memory initialization [all along](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/pull/44) and not the result of a bad kernel driver.

If using a Linux kernel released before 6.15, the change in this [patch](https://git.kernel.org/pub/scm/linux/kernel/git/vireshk/pm.git/patch/?id=f2d32942026c05acc49d5f445dd38931419967aa) needs to be applied to enable frequency scaling with a maximum clock speed of 1.2Ghz. Alternatively, frequency scaling will work without patching the kernel if the bootloader sets the CPU clock to 1GHz (`make CLOCKSPRESET=CPU_1000_DDR_800`), but that will be the maximum available frequency to the operating system.

### Marvell repos
The mv-ddr repo is used by the A3700-utils repo to make the `a3700_tool` target which is an executable. The executable gets copied (and renamed) to `A3700-utils-marvell/tim/ddr/ddr_tool` before being run by `A3700-utils-marvell/scripts/buildtim.sh`. The program generates the `ddr_static.txt` file in `A3700-utils-marvell/tim/ddr`. The contents of the file then get inserted by the `buildtim.sh` script into the `atf-ntim.txt` file used by TF-A to build the firmware image. The `ddr_static.txt` file contains instructions used to initialize memory.

Globalscale's repos produce a `ddr_static.txt` file that differs from Marvell's in [one place](https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell/commit/4208ad5f2d1cee6125d3047ea1aac90a051e3d16). However, Marvell's version is what is currently known to be stable so that is what is used.
