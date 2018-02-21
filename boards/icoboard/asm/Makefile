LINK=riscv32-unknown-elf-gcc -march=RV32I -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp
DUMP=riscv32-unknown-elf-objdump
COPY=riscv32-unknown-elf-objcopy

all: blink-test.dat

blink-test.o: blink-test.s
	$(LINK) -o blink-test.o blink-test.s

blink-test.bin: blink-test.o
	$(DUMP) -d blink-test.o
	$(COPY) -O binary blink-test.o blink-test.bin

blink-test.dat: blink-test.bin
	hexdump -v -f hexdump-format-byte blink-test.bin > blink-test.dat

clean:
	-rm *.o *.bin *.dat