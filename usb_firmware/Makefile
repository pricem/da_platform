#   Makefile for CD player Nexys2 USB firmware
#   Michael Price

#   Adapted from USB-JTAG project (Kolja Waschk, ixo.de)
#   License: GPL v2

LIBDIR=fx2
LIB=libfx2.lib

CC=sdcc
CFLAGS+=-mmcs51 --no-xinit-opt -I${LIBDIR}

AS=asx8051
ASFLAGS+=-plosgff

LDFLAGS=--code-loc 0x0000 --code-size 0x1800
LDFLAGS+=--xram-loc 0x1800 --xram-size 0x0800
LDFLAGS+=-Wl '-b USBDESCSEG = 0xE100'
LDFLAGS+=-L ${LIBDIR}

%.rel : %.a51
	$(AS) $(ASFLAGS) $<

%.rel : %.c
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

default: std.hex

std.hex: vectors.rel main.rel dscr.rel startup.rel ${LIBDIR}/${LIB}
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $+ 

${LIBDIR}/${LIB}:
	make -C ${LIBDIR}

dscr.rel: dscr.a51

.PHONY: clean distclean

clean:
	make -C ${LIBDIR} clean
	rm -f *.lst *.asm *.lib *.sym *.rel *.mem *.map *.rst *.lnk *.hex

distclean: clean

