CC=riscv32-unknown-elf-gcc
CFLAGS=-I../libtinyc -I../libspu32 -march=rv32i -static -nostdlib -fno-builtin-printf -O3 -fno-inline -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -L../libspu32 -lspu32 -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

DUMP=riscv32-unknown-elf-objdump
COPY=riscv32-unknown-elf-objcopy

all: dhrystone.o dhrystone_main.bin

%.bin: %.elf
	$(COPY) -O binary $< $@

%.elf: %.o
	$(CC) $(CFLAGS) -o $@ crt0.s $< $(LDFLAGS) dhrystone.o
	$(DUMP) -d $@

%.o: %.c 
	$(CC) $(CFLAGS) -c $<

clean:
	rm -rf *.o *.elf *.bin
