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

The build requires some basic UNIX tools (GNU make, curl, etc),
	and will attempt to download a complete toolchain (compiler, SDK, etc)
	into the [./util][] subdirectory.

You will however need to separately download the
	[JLink utilities from Segger](https://www.segger.com/downloads/jlink/)
	in order to flash the board during the `make install` phase.

See [./Makefile](./Makefile) for details.

### build notes

- The specific development board in use is
	[PCA10040](https://www.keil.com/boards2/nordicsemiconductors/nrf52pca10040/).
- This should work on macOS and Linux, but was only tested on the former.
- The author uses [Vim](https://www.vim.org/), the toolchain is geared to this.
- The [.ycm_extra_conf.py](.ycm_extra_conf.py) file allows for autocompletion
	in Vim using [YouCompleteMe](https://github.com/Valloric/YouCompleteMe);
	it's not perfect but goes a long way.
- The build system generates [cscope](http://cscope.sourceforge.net/) definitions;
	these are very useful when used with <https://github.com/vim-scripts/autoload_cscope.vim>.

## A Bug

TLDR: simultaneously advertising and scanning for advertisements
	causes PWM output on a GPIO pin to start a low-frequency frequency drift (LFO).

This bug may possibly reside in:

- nRF52832 chip
- SD132 SoftDevice
- nRF52 14.2.0 SDK

Bug details are in the [companion thread in Nordic's DevZone](https://devzone.nordicsemi.com/f/nordic-q-a/32389/sd_ble_gap_scan_start-induces-lfo-jitter-instability-in-pwm-output).

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
