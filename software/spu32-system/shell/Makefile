include ../../Makefile.vars

CC=${RV_GCC}
CFLAGS=-I../libtinyc -march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=${RV_OBJCOPY}
DUMP=${RV_OBJDUMP}

all: shell.bin


%.bin: %.elf
	$(COPY) -O binary $< $@

shell.elf: ./*.c crt0.s ../bios_calls/*.* ../libtinyc/*.*
	$(CC) $(CFLAGS) -o $@ shell.c crt0.s $(LDFLAGS)

dump: shell.elf
	$(DUMP) -d $<


clean:
	rm -rf *.o *.elf *.bin
