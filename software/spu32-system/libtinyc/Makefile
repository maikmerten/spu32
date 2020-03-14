CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libbioscalls -static -march=rv32im -mno-div -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=riscv64-unknown-elf-ar
ARFLAGS=rs

DUMP=riscv64-unknown-elf-objdump

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
