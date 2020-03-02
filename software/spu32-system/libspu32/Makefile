CC=riscv64-unknown-elf-gcc
CFLAGS=-static -march=rv32i -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=riscv64-unknown-elf-ar
ARFLAGS=rs

DUMP=riscv64-unknown-elf-objdump

all: libspu32.a

%.o: %.c
	$(CC) $(CFLAGS) -c $<
	$(DUMP) -d $@

libspu32.a: libspu32.o
	$(AR) $(ARFLAGS) $@ $<

clean:
	-rm *.o *.a
