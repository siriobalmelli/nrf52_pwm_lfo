# nrf52_pwm_lfo

This is a skeleton project to prove a bug which may reside in:

- nRF52832 chip
- SD132 SoftDevice
- nRF52 14.2.0 SDK

TLDR: scanning for advertisements causes PWM output on a GPIO pin
	to start a low-frequency drift back and forth (LFO).

## Build System Demonstration

This project also does double duty as a toolchain demonstration
	for building nRF52 projects with `gcc` and `make`.

The build requires some basic UNIX tools (GNU make, curl, etc),
	and will attempt to download a complete toolchain (compiler, SDK, etc)
	into the [./util][] subdirectory.

You will however need to separately download the
	[JLink utilities from Segger](https://www.segger.com/downloads/jlink/)
	in order to flash the board during the `make install` phase.

See [./Makefile][] for details.

### Build system notes

- The author uses [Vim](https://www.vim.org/), the toolchain is geared to this.
- The [.ycm_extra_conf.py](.ycm_extra_conf.py) file allows for autocompletion
	in Vim using [YouCompleteMe](https://github.com/Valloric/YouCompleteMe);
	it's not perfect but goes a long way.
- The build system generates [cscope](http://cscope.sourceforge.net/) definitions;
	these are very useful when used with <https://github.com/vim-scripts/autoload_cscope.vim>.
