CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -I../libspu32 -march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -L../libspu32 -lspu32 -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=riscv64-unknown-elf-objcopy

.PHONY: clean


all: argtest.bin mandel.bin minmemtest.bin memtest.bin dhryston.bin chreact.bin vgadraw.bin showfont.bin ls.bin mkdir.bin rm.bin cd.bin mv.bin print.bin cp.bin


%.bin: %.elf
	$(COPY) -O binary $< $@

argtest.elf: ./argtest/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ argtest/argtest.c crt0.s $(LDFLAGS)

mandel.elf: ./mandel/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ mandel/mandel.c crt0.s $(LDFLAGS)

minmemtest.elf: ./minmemtest/*.* crt0.s
	$(CC) $(CFLAGS) -o $@ minmemtest/minmemtest.c crt0.s $(LDFLAGS)

memtest.elf: ./memtest/*.* crt0.s ../libtinyc/*.a ../libspu32/*.a
	$(CC) $(CFLAGS) -o $@ memtest/memtest.c crt0.s $(LDFLAGS)

dhryston.bin: ./dhrystone/*.* ../libtinyc/*.a
	cd dhrystone && $(MAKE)
	cp dhrystone/dhrystone_main.bin dhryston.bin

chreact.elf: ./chainreaction/*.* crt0.s ../libtinyc/*.a ../libspu32/*.a
	$(CC) $(CFLAGS) -o $@ chainreaction/chainreaction.c crt0.s $(LDFLAGS)

vgadraw.elf: ./vgadraw/*.* crt0.s ../libtinyc/*.a ../libspu32/*.a
	$(CC) $(CFLAGS) -o $@ vgadraw/vgadraw.c crt0.s $(LDFLAGS)

showfont.elf: ./showfont/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ showfont/showfont.c crt0.s $(LDFLAGS)

# command line tools
ls.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/ls.c cmds/shared.c crt0.s $(LDFLAGS)

mkdir.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/mkdir.c cmds/shared.c crt0.s $(LDFLAGS)

rm.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/rm.c cmds/shared.c crt0.s $(LDFLAGS)

cd.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/cd.c cmds/shared.c crt0.s $(LDFLAGS)

mv.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/mv.c cmds/shared.c crt0.s $(LDFLAGS)

print.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/print.c cmds/shared.c crt0.s $(LDFLAGS)

cp.elf: ./cmds/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ cmds/cp.c cmds/shared.c crt0.s $(LDFLAGS)


clean:
	cd dhrystone && $(MAKE) clean
	rm -rf *.o *.elf *.bin
