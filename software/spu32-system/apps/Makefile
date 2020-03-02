CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

COPY=riscv64-unknown-elf-objcopy

.PHONY: clean


all: argtest.bin mandel.bin


%.bin: %.elf
	$(COPY) -O binary $< $@

argtest.elf: ./argtest/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ argtest/argtest.c crt0.s $(LDFLAGS)

mandel.elf: ./mandel/*.* crt0.s ../libtinyc/*.a
	$(CC) $(CFLAGS) -o $@ mandel/mandel.c crt0.s $(LDFLAGS)



clean:
	rm -rf *.o *.elf *.bin
