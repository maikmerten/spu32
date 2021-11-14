include ../../Makefile.vars

CC=${RV_GCC}
CFLAGS=-I../libbioscalls -static -march=rv32im -mno-div -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=${RV_AR}
ARFLAGS=rs

DUMP=${RV_OBJDUMP}

.PHONY: clean dump

all: libtinyc.a

dump: libtinyc.o
	$(DUMP) -d $<


%.o: %.c ../bios_calls/bios_calls.c
	$(CC) $(CFLAGS) -c $^


%.a: %.o
	$(AR) $(ARFLAGS) $@ $<



clean:
	-rm *.o *.a
