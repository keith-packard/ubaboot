# Copyright 2017 by Robert Evans (rrevans@gmail.com)
#
# This file is part of ubaboot.
#
# ubaboot is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ubaboot is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ubaboot.  If not, see <http://www.gnu.org/licenses/>.

# For best results use a recent version of GNU make.
# Tested with GNU Make 4.1

TOP ?= .
MCU = atmega32u4
FORMAT = ihex
TARGET ?= ubaboot
SRCS += ubaboot.S
SRCS += usbdesc.c
LDMAP = $(TOP)/ubaboot.lds
MAKEFILE = Makefile

vpath % $(TOP)

AVRDUDE_PROGRAMMER = -c usbtiny -B10
AVRDUDE_FLAGS = -p $(MCU) $(AVRDUDE_PORT) $(AVRDUDE_PROGRAMMER)
AVRDUDE_WRITE_FLASH = -U flash:w:$(TARGET).hex -U hfuse:w:0x9e:m
AVRDUDE_VERIFY_FLASH = -U flash:v:$(TARGET).hex -U hfuse:v:0x9e:m

CFLAGS += $(TARGET_CFLAGS)
CFLAGS += -std=gnu11
CFLAGS += -Os -g
CFLAGS += -D_GNU_SOURCE
CFLAGS += -mmcu=$(MCU)
CFLAGS += -Wall -Wextra -Wstrict-prototypes -Werror -Wno-unused-function
CFLAGS += -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums
CFLAGS += -ffreestanding -nostdlib
LDFLAGS = -Wl,-Map=$(TARGET).map,--cref
LDFLAGS += -T $(LDMAP)

AVR_CC = avr-gcc
AVR_OBJCOPY = avr-objcopy
AVR_OBJDUMP = avr-objdump
AVR_SIZE = avr-size
AVR_NM = avr-nm
AVRDUDE = avrdude

RM = rm -f
MV = mv -f
CP = cp -f
SED = sed

OBJS += $(patsubst %.c,%.o,$(filter %.c,$(SRCS)))
OBJS += $(patsubst %.S,%.o,$(filter %.S,$(SRCS)))
DEPS += $(OBJS:.o=.d)

all: subdirs
build: elf hex lss sym
elf: $(TARGET).elf
hex: $(TARGET).hex
lss: $(TARGET).lss
sym: $(TARGET).sym

$(OBJS): $(MAKEFILE)
elf hex lss sym: $(MAKEFILE)

isptest:
	$(AVRDUDE) $(AVRDUDE_FLAGS)
verify: $(TARGET).hex
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_VERIFY_FLASH)
program: build $(TARGET).hex
	$(AVRDUDE) $(AVRDUDE_FLAGS) $(AVRDUDE_WRITE_FLASH)

-include $(DEPS)

.SUFFIXES: .elf .hex .lss .sym

%.hex: %.elf
	$(AVR_OBJCOPY) -O $(FORMAT) -R .eeprom $< $@
%.lss: %.elf
	$(AVR_OBJDUMP) -h -S $< > $@
%.sym: %.elf
	$(AVR_NM) -n $< > $@

$(TARGET).elf: $(OBJS) $(LDMAP) $(MAKEFILE)
	$(AVR_CC) $(CFLAGS) $(OBJS) --output $@ $(LDFLAGS)
	$(AVR_SIZE) $(TARGET).elf

define mkdeps =
$(CP) $*.d $*.d.tmp
$(SED) -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
	-e '/^$$/ d' -e 's/$$/ :/' < $*.d >> $*.d.tmp
$(MV) $*.d.tmp $*.d
endef

%.o: %.c
	$(AVR_CC) -MD -c $(CFLAGS) $< -o $@
	@$(mkdeps)

%.o: %.S
	$(AVR_CC) -MD -c $(CFLAGS) $< -o $@
	@$(mkdeps)

clean: clean-local subdirs-clean subdirs-rm

clean-local:
	$(RM) $(TARGET).hex $(TARGET).elf \
		$(TARGET).map $(TARGET).sym $(TARGET).lss \
		$(OBJS) $(DEPS)

BINDIR=/usr/local/bin
LIBDIR=/usr/local/share/ubaboot

install: install-bin subdirs-install

install-bin: ubaboot.py
	install -D ubaboot.py $(BINDIR)/ubaboot

install-hex: $(TARGET).hex
	install -D $(TARGET).hex -m 644 $(LIBDIR)/$(TARGET).hex

TARGETS=feather teensy itsybitsy3v itsybitsy5v uduino

subdirs:
	+for target in $(TARGETS); do \
		mkdir -p $${target}; \
		def=`echo $${target} | tr a-z A-Z`; \
		(cd $${target} && make TOP=.. TARGET=ubaboot-$${target} TARGET_CFLAGS=-D$${def} -f ../Makefile hex) || exit 1; \
		cp $${target}/ubaboot-$${target}.hex .; \
	done

subdirs-install:
	+for target in $(TARGETS); do \
		mkdir -p $${target}; \
		def=`echo $${target} | tr a-z A-Z`; \
		(cd $${target} && make TOP=.. TARGET=ubaboot-$${target} TARGET_CFLAGS=-D$${def} -f ../Makefile install-hex) || exit 1; \
	done

subdirs-clean:
	+for target in $(TARGETS); do \
		mkdir -p $${target}; \
		def=`echo $${target} | tr a-z A-Z`; \
		(cd $${target} && make TOP=.. TARGET=ubaboot-$${target} TARGET_CFLAGS=-D$${def} -f ../Makefile clean-local) || exit 1; \
	done

subdirs-rm: subdirs-clean
	+for target in $(TARGETS); do \
		rmdir $${target}; \
	done

.PHONY: all build elf hex lss sym clean clean-local subdirs subdirs-install subdirs-clean
