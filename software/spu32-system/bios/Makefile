include ../../Makefile.vars

CC=${RV_GCC}
CFLAGSBIOS=-march=rv32im -mno-div -mabi=ilp32 -msave-restore -static -nostdlib -fno-builtin -ffreestanding -Os -fdata-sections -ffunction-sections
LDFLAGSBIOS=-lgcc -Tbios_link.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

DUMP=${RV_OBJDUMP}
COPY=${RV_OBJCOPY}
TRUNCATE=truncate
CP=cp

all: bios_24k.bin

bios_24k.bin: bios.bin
	$(CP) $< $@
	$(TRUNCATE) -s 24576 $@

%.bin: %.elf
	$(COPY) -O binary $< $@


bios.elf: bios_crt0.s bios.o bios_spi.o bios_sdcard.o bios_uart.o bios_video.o bios_fatfs.o diskio_spu32.o ff.o
	$(CC) $(CFLAGSBIOS) -o $@ $^ $(LDFLAGSBIOS)

bios.o: bios.c bios_shared.h
	$(CC) $(CFLAGSBIOS) -c $<

%.o: %.c
	$(CC) $(CFLAGSBIOS) -c $<

diskio_spu32.o: fatfs/diskio_spu32.c
	$(CC) $(CFLAGSBIOS) -c $<

ff.o: fatfs/ff.c
	$(CC) $(CFLAGSBIOS) -c $<

dump: bios.elf
	$(DUMP) -d $<


clean:
	rm -rf *.o *.elf *.bin
