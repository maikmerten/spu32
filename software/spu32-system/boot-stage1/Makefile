CC=riscv64-unknown-elf-gcc
CFLAGS=-I../libtinyc -march=rv32i -mabi=ilp32 -static -nostdlib -fno-builtin-printf -Os -fPIC -fdata-sections -ffunction-sections
LDFLAGS=-L../libtinyc -ltinyc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

# https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

COPY=riscv64-unknown-elf-objcopy
DUMP=riscv64-unknown-elf-objdump
TRUNCATE=truncate
CP=cp

all: stage1_4k.bin

stage1_4k.bin: stage1.bin
	$(CP) $< stage1_4k.bin
	$(TRUNCATE) --size 4096 $@


%.bin: %.elf
	$(COPY) -O binary $< $@

stage1.elf: stage1.c crt0.s 
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)


dump: stage1.elf
	$(DUMP) -d $<

clean:
	rm -rf *.o *.elf *.bin
