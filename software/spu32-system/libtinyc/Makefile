CC=riscv64-unknown-elf-gcc
CFLAGS=-static -march=rv32i -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=riscv64-unknown-elf-ar
ARFLAGS=rs

DUMP=riscv64-unknown-elf-objdump

all: libtinyc.a

%.o: %.c
	$(CC) $(CFLAGS) -c $<
	$(DUMP) -d $@

libtinyc.a: libtinyc.o
	$(AR) $(ARFLAGS) $@ $<

clean:
	-rm *.o *.a
