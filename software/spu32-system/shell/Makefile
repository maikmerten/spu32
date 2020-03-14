CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=riscv64-unknown-elf-objcopy
DUMP=riscv64-unknown-elf-objdump
TRUNCATE=truncate
CP=cp

all: shell.bin


%.bin: %.elf
	$(COPY) -O binary $< $@

shell.elf: ./*.c crt0.s ../bios_calls/*.* ../libbioscalls/*.* ../libtinyc/*.*
	$(CC) $(CFLAGS) -o $@ shell.c crt0.s $(LDFLAGS)

dump: shell.elf
	$(DUMP) -d $<


clean:
	rm -rf *.o *.elf *.bin
