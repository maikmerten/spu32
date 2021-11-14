include ../Makefile.vars

LINK=${RV_GCC} -march=rv32i -mabi=ilp32 -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp
DUMP=${RV_OBJDUMP}
COPY=${RV_OBJCOPY}

all: blink-test.dat blink-test.bin uart-echo.dat spi-test.dat trap-test.dat timer-test.dat bootrom.dat bootrom.bin bootrom_onlyuart.dat bootrom_onlyuart.bin

%.o: %.s
	$(LINK) -o $@ $<

%.bin: %.o
	$(DUMP) -d $<
	$(COPY) -O binary $< $@

%.dat: %.bin
	hexdump -v -e '1/1 "%02x" "\n"' $< > $@

clean:
	-rm *.o *.bin *.dat
