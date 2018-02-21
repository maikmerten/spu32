LINK=riscv32-unknown-elf-gcc -march=RV32I -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp
DUMP=riscv32-unknown-elf-objdump
COPY=riscv32-unknown-elf-objcopy

all: blink-test.dat

%.o: %.s
	$(LINK) -o $@ $<

%.bin: %.o
	$(DUMP) -d $<
	$(COPY) -O binary $< $@

%.dat: %.bin
	hexdump -v -f hexdump-format-byte $< > $@

clean:
	-rm *.o *.bin *.dat