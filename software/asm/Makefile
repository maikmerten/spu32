LINK=riscv32-unknown-elf-gcc -march=rv32i -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp
DUMP=riscv32-unknown-elf-objdump
COPY=riscv32-unknown-elf-objcopy

all: blink-test.dat blink-test.bin uart-echo.dat spi-test.dat trap-test.dat timer-test.dat bootrom.dat bootrom.bin

%.o: %.s
	$(LINK) -o $@ $<

%.bin: %.o
	$(DUMP) -d $<
	$(COPY) -O binary $< $@

%.dat: %.bin
	hexdump -v -e '1/1 "%02x" "\n"' $< > $@

clean:
	-rm *.o *.bin *.dat
