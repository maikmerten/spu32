CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -I../libspu32 -march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -L../libspu32 -lspu32 -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=riscv64-unknown-elf-objcopy

.PHONY: clean


all: argtest.bin mandel.bin memtest.bin dhryston.bin chreact.bin


%.bin: %.elf
	$(COPY) -O binary $< $@

argtest.elf: ./argtest/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ argtest/argtest.c crt0.s $(LDFLAGS)

mandel.elf: ./mandel/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ mandel/mandel.c crt0.s $(LDFLAGS)

memtest.elf: ./memtest/*.* crt0.s ../libtinyc/*.a ../libspu32/*.a
	$(CC) $(CFLAGS) -o $@ memtest/memtest.c crt0.s $(LDFLAGS)

dhryston.bin: ./dhrystone/*.* ../libtinyc/*.a
	cd dhrystone && $(MAKE)
	cp dhrystone/dhrystone_main.bin dhryston.bin

chreact.elf: ./chainreaction/*.* crt0.s ../libtinyc/*.a ../libspu32/*.a
	$(CC) $(CFLAGS) -o $@ chainreaction/chainreaction.c crt0.s $(LDFLAGS)

clean:
	cd dhrystone && $(MAKE) clean
	rm -rf *.o *.elf *.bin
