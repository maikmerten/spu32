CC=riscv32-unknown-elf-gcc
CFLAGS=-I./libtinyc -march=rv32i -static -nostdlib -fno-builtin-printf -Os -fPIC
LDFLAGS=-L./libtinyc -ltinyc -Tlink.ld
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

DUMP=riscv32-unknown-elf-objdump
COPY=riscv32-unknown-elf-objcopy

all: example.bin

%.bin: %.elf
	$(COPY) -O binary $< $@

%.elf: %.o
	$(CC) $(CFLAGS) -o $@ crt0.s $< $(LDFLAGS)
	$(DUMP) -d $@

%.o: %.c libtinyc/*.h libtinyc/*.c
	cd libtinyc && $(MAKE)
	$(CC) $(CFLAGS) -c $<

clean:
	rm -rf *.o *.elf *.bin
