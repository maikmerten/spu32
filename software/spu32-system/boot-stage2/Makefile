CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -march=rv32im -mno-div -mabi=ilp32 -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=riscv64-unknown-elf-objcopy
DUMP=riscv64-unknown-elf-objdump
TRUNCATE=truncate
CP=cp

all: stage2_4k.bin

stage2_4k.bin: stage2.bin
	$(CP) $< $@
	$(TRUNCATE) -s 4096 $@

%.bin: %.elf
	$(COPY) -O binary $< $@

stage2.elf: ./*.c crt0.s ../bios_calls/*.h ../bios_calls/*.c ../libtinyc/*.h ../libtinyc/*.c
	$(CC) $(CFLAGS) -o $@ stage2.c crt0.s $(LDFLAGS)

dump: stage2.elf
	$(DUMP) -d $<


clean:
	rm -rf *.o *.elf *.bin
