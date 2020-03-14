CC=riscv64-unknown-elf-gcc
CFLAGS=-static -march=rv32im -mno-div -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=riscv64-unknown-elf-ar
ARFLAGS=rs

DUMP=riscv64-unknown-elf-objdump

.PHONY: clean dump

all: libspu32.a

dump: libspu32.o
	$(DUMP) -d $<


%.o: %.c
	$(CC) $(CFLAGS) -c $<


%.a: %.o
	$(AR) $(ARFLAGS) $@ $<



clean:
	-rm *.o *.a
