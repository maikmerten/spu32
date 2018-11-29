CC=riscv32-unknown-elf-gcc
CFLAGS=-static -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=riscv32-unknown-elf-ar
ARFLAGS=rs

DUMP=riscv32-unknown-elf-objdump

all: libtinyc.a

%.o: %.c
	$(CC) $(CFLAGS) -c $<
	$(DUMP) -d $@

libtinyc.a: libtinyc.o
	$(AR) $(ARFLAGS) $@ $<

clean:
	-rm *.o *.a
