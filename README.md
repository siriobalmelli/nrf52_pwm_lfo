# nrf52_pwm_lfo

This is a skeleton project for the
	Nordic [nRF52832](https://www.nordicsemi.com/Products/nRF52-Series-SoC)
	bluetooth SoC, using [SoftDevice S132](https://www.nordicsemi.com/eng/Products/S132-SoftDevice)
	and compiling with the [gcc ARM toolchain](https://developer.arm.com/open-source/gnu-toolchain/gnu-rm).

It exists to:

- demonstrate the build system
- highlight a bug with an LFO in the PWM subsystem under certain conditions

## build system demonstration

This project also does double duty as a toolchain demonstration
	for building nRF52 projects with `gcc` and `make`.

### How to build

The build requires some basic UNIX tools; on a Ubuntu machine this looks like:

```bash
sudo apt-get install make curl unzip tar
```

Once you have those, proceed with:

```bash
git clone https://github.com/siriobalmelli/nrf52_pwm_lfo.git
cd nrf52_pwm_lfo
make
```

You will see that `make` will download a complete toolchain
	(compiler, SDK, etc) into the [./util](./util) subdirectory
	of the project.

Before you can install the firmware on a device, however, you need to separately
	download the proprietary [JLink utilities from Segger](https://www.segger.com/downloads/jlink/).
You can verify these are installed with:

```bash
which JLinkExe
```

Once that's sorted, plug an nRF52-DK into a USB port and flash the firmware with:

```bash
make install
```

### build system notes

- The specific development board in use is
	[PCA10040](https://www.keil.com/boards2/nordicsemiconductors/nrf52pca10040/).
- The author uses [Vim](https://www.vim.org/), the toolchain is geared to this.
- The [.ycm_extra_conf.py](.ycm_extra_conf.py) file allows for autocompletion
	in Vim using [YouCompleteMe](https://github.com/Valloric/YouCompleteMe);
	it's not perfect but goes a long way.
- The build system generates [cscope](http://cscope.sourceforge.net/) definitions;
	these are very useful when used with <https://github.com/vim-scripts/autoload_cscope.vim>.

See [./Makefile](./Makefile) for details.

## A Bug

TLDR: simultaneously advertising and scanning for advertisements
	causes PWM output on a GPIO pin to start a low-frequency frequency drift (LFO).

This bug may possibly reside in:

- nRF52832 chip
- SD132 SoftDevice
- nRF52 14.2.0 SDK

Bug details are in the [companion thread in Nordic's DevZone](https://devzone.nordicsemi.com/f/nordic-q-a/32389/sd_ble_gap_scan_start-induces-lfo-jitter-instability-in-pwm-output).

Visual demonstration: a [video of scope reading on the GPIO](https://youtu.be/AUccm7ITvBA)

### Reproduction

To reproduce the bug, compile the project normally and execute
	in the presence of some bluetooth advertisements.

The bug can be avoided by building with certain code disabled:

| technique                        | build command     | result       |
| -------------------------------- | ----------------- | ------------ |
| do not advertise                 | `make nolfo-adv`  | no LFO       |
| do not scan for advertisements   | `make nolfo-scan` | no LFO       |
| neither advertising nor scanning | `make nolfo`      | no LFO       |
| both scanning and advertising    | `make`            | LFO behavior |
