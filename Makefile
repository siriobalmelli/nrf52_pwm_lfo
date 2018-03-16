# ARM GCC makefile for N52832 with s132 SoftDevice
# 	(c) 2018 Sirio, Balmelli Analog & Digital
#
# Self-contained build in this directory tree, except for the Segger JLink tools
#+	which you'll have to install separately
# See TOOLCHAINS section below for details



###########################
###	FUN WITH FLAGS	###
###########################

# common defines (compiler + assembler)
DEFINES :=	-DBOARD_PCA10040 \
		-DSOFTDEVICE_PRESENT \
		-DNRF52 \
		-DNRF52832_XXAA \
		-DNRF52_PAN_74 \
		-DS132 \
		-DSWI_DISABLE0 \
		-DNRF_SD_BLE_API_VERSION=5 \
		-DFLOAT_ABI_HARD \
		-DCONFIG_GPIO_AS_PINRESET \
		-DNRF_LOG_USES_RTT=1

# architecture flags (compiler + linker)
ARCH_FLAGS := -mcpu=cortex-m4 -mthumb -mabi=aapcs -mfloat-abi=hard -mfpu=fpv4-sp-d16
# NO! lto breaks SoftDevice
#ARCH_FLAGS += -flto

# compiler defines
CFLAGS += $(DEFINES)
CFLAGS += $(ARCH_FLAGS)
# compiler flags
CFLAGS +=  -Wall -Werror -Os -g3 -std=gnu99
# keep every function in separate section, this allows linker to discard unused ones
CFLAGS += -ffunction-sections -fdata-sections -fno-strict-aliasing
CFLAGS += -fno-builtin --short-enums 

# Assembler flags common to all targets
ASMFLAGS += $(DEFINES)
ASMFLAGS += $(ARCH_FLAGS)
ASMFLAGS += -g3
ASMFLAGS += -x assembler-with-cpp

# Linker flags
LDFLAGS += $(ARCH_FLAGS)
LDFLAGS += -L $(SDK_ROOT)/components/toolchain/gcc
# let linker dump unused sections
LDFLAGS += -Wl,--gc-sections
LDFLAGS += --specs=nano.specs
 
# this comes last - after everything else that may require it
LDADDL += -lc -lnosys -lm



###########################
###	TARGETS		###
###########################

# project sources
SRC :=\
	$(wildcard src/*.c)
INCL :=\
	./include

# project name
PJT := nrf52_pwm_lfo
# build everything here
BLD := ./build

.PHONY: all
all : toolchain $(BLD)/out.hex | doc
.PHONY: patterns
patterns: PATTERNS =./patterns.hex
patterns: all

.PHONY: clean
clean :
	rm -rf $(BLD) cscope*

.PHONY: install
install : all
	$(NRFJPROG) -f nrf52 --program $(BLD)/out.hex --chiperase --reset

# cscope for code navigation
# '-k' flag for cscope disables indexing /usr/include
.PHONY: doc
doc : $(OBJ)
	if which cscope >/dev/null; then \
		cscope -b -q -U -k $(addprefix -I ,$(SOFT_INCL) $(SDK_INCL) $(INCL)) $(BLD)/*.c; \
	fi



###########################
###	TOOLCHAIN	###
###########################

# Platform-specific (for tools that follow)
PLATFORM := $(shell uname)

# Nordic's SDK
SDK_BASE := nRF5_SDK_14.2.0_17b948a
SDK_ROOT := ./util/$(SDK_BASE)

$(SDK_ROOT).zip :
	mkdir -p $(dir $@)
	curl -R -L -o $@ https://developer.nordicsemi.com/nRF5_SDK/nRF5_SDK_v14.x.x/$(SDK_BASE).zip
$(SDK_ROOT) : $(SDK_ROOT).zip
	unzip $< -d $(dir $@)
	touch $@


# GNU Toolchain
ifeq ($(PLATFORM),Darwin)
GNU_ABI = mac
else
GNU_ABI = linux
endif

GNU_PREFIX := arm-none-eabi
GNU_BASE = gcc-$(GNU_PREFIX)-7-2017-q4-major
GNU_TAR = $(GNU_BASE)-$(GNU_ABI).tar.bz2
GNU_ROOT = util/$(GNU_BASE)

CC      = $(GNU_ROOT)/bin/$(GNU_PREFIX)-gcc
OBJCOPY = $(GNU_ROOT)/bin/$(GNU_PREFIX)-objcopy

util/$(GNU_TAR) :
	mkdir -p $(dir $@)
	curl -R -L -o $@ https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-rm/7-2017q4/$(GNU_TAR)
$(GNU_ROOT) : util/$(GNU_TAR)
	tar -xjf $< -C $(dir $@)
	touch $@


# Nordic Tools
ifeq ($(PLATFORM),Darwin)
TOOLS_ABI = OSX
TOOLS_URL = https://www.nordicsemi.com/eng/nordic/download_resource/53402/19/46342169/99977
else
TOOLS_ABI = Linux-x86_64
TOOLS_URL = https://www.nordicsemi.com/eng/nordic/download_resource/51386/27/9440329/94917
endif

TOOLS_ROOT = ./util/nRF5x-Command-Line-Tools_9_7_2_$(TOOLS_ABI)
MERGEHEX = $(TOOLS_ROOT)/mergehex/mergehex
NRFJPROG = $(TOOLS_ROOT)/nrfjprog/nrfjprog

$(TOOLS_ROOT).tar :
	mkdir -p $(dir $@)
	curl -R -L -o $@ $(TOOLS_URL)
$(TOOLS_ROOT) : $(TOOLS_ROOT).tar
	mkdir -p $@
	tar -xf $< -C $@

# master toolchain target
.PHONY: toolchain
toolchain : $(SDK_ROOT) $(GNU_ROOT) $(TOOLS_ROOT)

###########################
###	SDK		###
###########################

# softdevice
SOFT_BASE = $(SDK_ROOT)/components/softdevice/s132
SOFT_INCL = $(SOFT_BASE)/headers
SOFT_DEV = $(SOFT_BASE)/hex/s132_nrf52_5.0.0_softdevice.hex

# device-specific (change these if using e.g. 528310)
SDK_SRC =\
  $(SDK_ROOT)/components/toolchain/gcc/gcc_startup_nrf52.S \
  $(SDK_ROOT)/components/toolchain/system_nrf52.c

# device-independent
SDK_SRC +=\
  $(SDK_ROOT)/components/ble/ble_services/ble_lbs/ble_lbs.c \
  $(SDK_ROOT)/components/ble/common/ble_advdata.c \
  $(SDK_ROOT)/components/ble/common/ble_conn_params.c \
  $(SDK_ROOT)/components/ble/common/ble_conn_state.c \
  $(SDK_ROOT)/components/ble/common/ble_srv_common.c \
  $(SDK_ROOT)/components/ble/nrf_ble_gatt/nrf_ble_gatt.c \
  $(SDK_ROOT)/components/boards/boards.c \
  $(SDK_ROOT)/components/drivers_nrf/clock/nrf_drv_clock.c \
  $(SDK_ROOT)/components/drivers_nrf/common/nrf_drv_common.c \
  $(SDK_ROOT)/components/drivers_nrf/gpiote/nrf_drv_gpiote.c \
  $(SDK_ROOT)/components/drivers_nrf/pwm/nrf_drv_pwm.c \
  $(SDK_ROOT)/components/drivers_nrf/timer/nrf_drv_timer.c \
  $(SDK_ROOT)/components/libraries/atomic_fifo/nrf_atfifo.c \
  $(SDK_ROOT)/components/libraries/balloc/nrf_balloc.c \
  $(SDK_ROOT)/components/libraries/button/app_button.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_backend_rtt.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_backend_serial.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_backend_uart.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_default_backends.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_frontend.c \
  $(SDK_ROOT)/components/libraries/experimental_log/src/nrf_log_str_formatter.c \
  $(SDK_ROOT)/components/libraries/experimental_memobj/nrf_memobj.c \
  $(SDK_ROOT)/components/libraries/experimental_section_vars/nrf_section_iter.c \
  $(SDK_ROOT)/components/libraries/hardfault/hardfault_implementation.c \
  $(SDK_ROOT)/components/libraries/pwr_mgmt/nrf_pwr_mgmt.c \
  $(SDK_ROOT)/components/libraries/scheduler/app_scheduler.c \
  $(SDK_ROOT)/components/libraries/strerror/nrf_strerror.c \
  $(SDK_ROOT)/components/libraries/timer/app_timer.c \
  $(SDK_ROOT)/components/libraries/util/app_error.c \
  $(SDK_ROOT)/components/libraries/util/app_error_weak.c \
  $(SDK_ROOT)/components/libraries/util/app_util_platform.c \
  $(SDK_ROOT)/components/libraries/util/nrf_assert.c \
  $(SDK_ROOT)/components/libraries/util/sdk_mapped_flags.c \
  $(SDK_ROOT)/components/softdevice/common/nrf_sdh.c \
  $(SDK_ROOT)/components/softdevice/common/nrf_sdh_ble.c \
  $(SDK_ROOT)/components/softdevice/common/nrf_sdh_soc.c \
  $(SDK_ROOT)/external/fprintf/nrf_fprintf.c \
  $(SDK_ROOT)/external/fprintf/nrf_fprintf_format.c \
  $(SDK_ROOT)/external/segger_rtt/SEGGER_RTT.c \
  $(SDK_ROOT)/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c \
  $(SDK_ROOT)/external/segger_rtt/SEGGER_RTT_printf.c

SDK_INCL =\
  $(SDK_ROOT)/components \
  $(SDK_ROOT)/components/ble/ble_dtm \
  $(SDK_ROOT)/components/ble/ble_racp \
  $(SDK_ROOT)/components/ble/ble_services/ble_ancs_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_ans_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_bas \
  $(SDK_ROOT)/components/ble/ble_services/ble_bas_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_cscs \
  $(SDK_ROOT)/components/ble/ble_services/ble_cts_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_dfu \
  $(SDK_ROOT)/components/ble/ble_services/ble_dis \
  $(SDK_ROOT)/components/ble/ble_services/ble_gls \
  $(SDK_ROOT)/components/ble/ble_services/ble_hids \
  $(SDK_ROOT)/components/ble/ble_services/ble_hrs \
  $(SDK_ROOT)/components/ble/ble_services/ble_hrs_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_hts \
  $(SDK_ROOT)/components/ble/ble_services/ble_ias \
  $(SDK_ROOT)/components/ble/ble_services/ble_ias_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_lbs \
  $(SDK_ROOT)/components/ble/ble_services/ble_lbs_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_lls \
  $(SDK_ROOT)/components/ble/ble_services/ble_nus \
  $(SDK_ROOT)/components/ble/ble_services/ble_nus_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_rscs \
  $(SDK_ROOT)/components/ble/ble_services/ble_rscs_c \
  $(SDK_ROOT)/components/ble/ble_services/ble_tps \
  $(SDK_ROOT)/components/ble/common \
  $(SDK_ROOT)/components/ble/nrf_ble_gatt \
  $(SDK_ROOT)/components/ble/nrf_ble_qwr \
  $(SDK_ROOT)/components/ble/peer_manager \
  $(SDK_ROOT)/components/boards \
  $(SDK_ROOT)/components/device \
  $(SDK_ROOT)/components/drivers_nrf/clock \
  $(SDK_ROOT)/components/drivers_nrf/common \
  $(SDK_ROOT)/components/drivers_nrf/comp \
  $(SDK_ROOT)/components/drivers_nrf/delay \
  $(SDK_ROOT)/components/drivers_nrf/gpiote \
  $(SDK_ROOT)/components/drivers_nrf/hal \
  $(SDK_ROOT)/components/drivers_nrf/i2s \
  $(SDK_ROOT)/components/drivers_nrf/lpcomp \
  $(SDK_ROOT)/components/drivers_nrf/pdm \
  $(SDK_ROOT)/components/drivers_nrf/power \
  $(SDK_ROOT)/components/drivers_nrf/ppi \
  $(SDK_ROOT)/components/drivers_nrf/pwm \
  $(SDK_ROOT)/components/drivers_nrf/qdec \
  $(SDK_ROOT)/components/drivers_nrf/rng \
  $(SDK_ROOT)/components/drivers_nrf/rtc \
  $(SDK_ROOT)/components/drivers_nrf/saadc \
  $(SDK_ROOT)/components/drivers_nrf/spi_master \
  $(SDK_ROOT)/components/drivers_nrf/spi_slave \
  $(SDK_ROOT)/components/drivers_nrf/swi \
  $(SDK_ROOT)/components/drivers_nrf/timer \
  $(SDK_ROOT)/components/drivers_nrf/twi_master \
  $(SDK_ROOT)/components/drivers_nrf/twis_slave \
  $(SDK_ROOT)/components/drivers_nrf/uart \
  $(SDK_ROOT)/components/drivers_nrf/usbd \
  $(SDK_ROOT)/components/drivers_nrf/wdt \
  $(SDK_ROOT)/components/libraries/atomic \
  $(SDK_ROOT)/components/libraries/atomic_fifo \
  $(SDK_ROOT)/components/libraries/balloc \
  $(SDK_ROOT)/components/libraries/button \
  $(SDK_ROOT)/components/libraries/cli \
  $(SDK_ROOT)/components/libraries/crc16 \
  $(SDK_ROOT)/components/libraries/crc32 \
  $(SDK_ROOT)/components/libraries/csense \
  $(SDK_ROOT)/components/libraries/csense_drv \
  $(SDK_ROOT)/components/libraries/ecc \
  $(SDK_ROOT)/components/libraries/experimental_log \
  $(SDK_ROOT)/components/libraries/experimental_log/src \
  $(SDK_ROOT)/components/libraries/experimental_memobj \
  $(SDK_ROOT)/components/libraries/experimental_section_vars \
  $(SDK_ROOT)/components/libraries/fds \
  $(SDK_ROOT)/components/libraries/fstorage \
  $(SDK_ROOT)/components/libraries/gpiote \
  $(SDK_ROOT)/components/libraries/hardfault \
  $(SDK_ROOT)/components/libraries/hci \
  $(SDK_ROOT)/components/libraries/led_softblink \
  $(SDK_ROOT)/components/libraries/low_power_pwm \
  $(SDK_ROOT)/components/libraries/mem_manager \
  $(SDK_ROOT)/components/libraries/mutex \
  $(SDK_ROOT)/components/libraries/pwm \
  $(SDK_ROOT)/components/libraries/pwr_mgmt \
  $(SDK_ROOT)/components/libraries/queue \
  $(SDK_ROOT)/components/libraries/scheduler \
  $(SDK_ROOT)/components/libraries/slip \
  $(SDK_ROOT)/components/libraries/strerror \
  $(SDK_ROOT)/components/libraries/timer \
  $(SDK_ROOT)/components/libraries/twi \
  $(SDK_ROOT)/components/libraries/twi_mngr \
  $(SDK_ROOT)/components/libraries/uart \
  $(SDK_ROOT)/components/libraries/usbd \
  $(SDK_ROOT)/components/libraries/usbd/class/audio \
  $(SDK_ROOT)/components/libraries/usbd/class/cdc \
  $(SDK_ROOT)/components/libraries/usbd/class/cdc/acm \
  $(SDK_ROOT)/components/libraries/usbd/class/hid \
  $(SDK_ROOT)/components/libraries/usbd/class/hid/generic \
  $(SDK_ROOT)/components/libraries/usbd/class/hid/kbd \
  $(SDK_ROOT)/components/libraries/usbd/class/hid/mouse \
  $(SDK_ROOT)/components/libraries/usbd/class/msc \
  $(SDK_ROOT)/components/libraries/usbd/config \
  $(SDK_ROOT)/components/libraries/util \
  $(SDK_ROOT)/components/softdevice/common \
  $(SDK_ROOT)/components/softdevice/s112/headers \
  $(SDK_ROOT)/components/softdevice/s112/headers/nrf52 \
  $(SDK_ROOT)/components/toolchain \
  $(SDK_ROOT)/components/toolchain/cmsis/include \
  $(SDK_ROOT)/components/toolchain/gcc \
  $(SDK_ROOT)/external/fprintf \
  $(SDK_ROOT)/external/segger_rtt


###########################
###	INTERNALS	###
###########################

# List of all object files expected.
# Double substitution so that .S assembler files become .S.o;
#+	while .c files become .o
OBJ = $(patsubst %,$(BLD)/%.o,$(patsubst %.c,%,$(notdir $(SDK_SRC) $(SRC))))


# Make build directory;
#+	dump includes and compiler flags into text files therein,
#+	for YCM to use in auto-completion; see .ycm_extra_conf.py
$(BLD) :
	mkdir -p $(BLD)
	@echo "$(DEFINES) $(ARCH_FLAGS) $(CFLAGS)" | tr ' ' '\n' | sort -u >$(BLD)/flags.txt
	@echo "$(SOFT_INCL) $(SDK_INCL) $(INCL)" | tr ' ' '\n' | sort -u >$(BLD)/includes.txt
	@echo "$(OBJ)" | tr ' ' '\n' | sort -u >$(BLD)/objects.txt


# Bring .c files into project so they can be compiled against with a pattern rule
#+	and keep them there so they can be used for auto-complete.
# Note that link MUST be hard or else timestamp will not update when target
#+	is edited.
.PRECIOUS: $(BLD)/%.c $(BLD)/%.S
$(BLD)/%.c $(BLD)/%.S :
	@src_="$(realpath $(filter %$(notdir $@),$(SDK_SRC) $(SRC)))"; \
	if test $$src_; then \
		ln -v $$src_ $@; \
	else \
		echo "no source path found for '$@'"; \
		exit 1; \
	fi

# slightly more specific rule to assemble .S into .o
$(BLD)/%.S.o : $(BLD)/%.S | $(BLD)
	$(CC) $(ASMFLAGS) $(addprefix -I,$(SOFT_INCL) $(SDK_INCL) $(INCL)) -c -o $@ $<
# Generic rule to build object files
# Build dir is order-only so that .o files are not re-made simply because the
#	build dir was later touched.
# NOTE that we also output intermedite assembly for debug purposes
$(BLD)/%.o : $(BLD)/%.c | $(BLD)
	@echo "$< -> $@"
	@$(CC) $(CFLAGS) $(addprefix -I,$(SOFT_INCL) $(SDK_INCL) $(INCL)) -c -o $@ $<
	@$(CC) $(CFLAGS) -S $(addprefix -I,$(SOFT_INCL) $(SDK_INCL) $(INCL)) -c -o $@.asm $<

# link application
# $(PJT).ld is the linker script
$(BLD)/$(PJT).out : $(OBJ) $(PJT).ld
	$(CC) -Wl,-Map=$(BLD)/$(PJT).map $(LDFLAGS) -T$(PJT).ld $(OBJ) $(LDADDL) -o $@

# Create a binary .hex file from an .out file
%.hex : %.out
	@echo Preparing: $@
	$(OBJCOPY) -O ihex $< $@

# Merge hex file with softdevice
$(BLD)/out.hex : $(BLD)/$(PJT).hex $(SOFT_DEV)
	$(MERGEHEX) --merge $(PATTERNS) $^ --output $@
