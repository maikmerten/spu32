include ../Makefile.vars

LINK=${RV_GCC} -march=rv32i -mabi=ilp32 -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp
DUMP=${RV_OBJDUMP}
COPY=${RV_OBJCOPY}

all: blink-test.dat blink-test.dat32 blink-test.bin uart-echo.dat uart-echo.dat32 spi-test.dat trap-test.dat timer-test.dat bootrom.dat bootrom.dat32 bootrom.bin bootrom_onlyuart.dat bootrom_onlyuart.dat32 bootrom_onlyuart.bin

%.o: %.s
	$(LINK) -o $@ $<

%.bin: %.o
	$(DUMP) -d $<
	$(COPY) -O binary $< $@

%.dat: %.bin
	hexdump -v -e '1/1 "%02x" "\n"' $< > $@

%.dat32: %.bin
	hexdump -v -e '1/4 "%08x" "\n"' $< > $@

clean:
	-rm *.o *.bin *.dat
