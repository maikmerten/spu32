CC=riscv64-unknown-elf-gcc
CFLAGS=-I./libtinyc -I./libspu32 -march=rv32im -mno-div -mabi=ilp32 -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L./libtinyc -ltinyc -L./libspu32 -lspu32 -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

DUMP=riscv64-unknown-elf-objdump
COPY=riscv64-unknown-elf-objcopy

all: example.bin interrupts.bin chainreaction.bin memtest.bin selftest.bin

%.bin: %.elf
	$(COPY) -O binary $< $@

%.elf: %.o
	$(CC) $(CFLAGS) -o $@ crt0.s $< $(LDFLAGS)
	$(DUMP) -d $@

%.o: %.c *.s libtinyc/*.h libtinyc/*.c libspu32/*.h libspu32/*.c
	cd libtinyc && $(MAKE)
	cd libspu32 && $(MAKE)
	$(CC) $(CFLAGS) -c $<

clean:
	rm -rf *.o *.elf *.bin
