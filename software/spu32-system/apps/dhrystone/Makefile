include ../../../Makefile.vars

CC=${RV_GCC}
CFLAGS=-I../../libtinyc -I../../libspu32 -march=rv32im -mno-div -mabi=ilp32 -static -nostdlib -fno-builtin-printf -O3 -fno-inline -fdata-sections -ffunction-sections
LDFLAGS=-L../../libtinyc -ltinyc -L../../libspu32 -lspu32 -lgcc -Tlink.ld -Xlinker --gc-sections
# useful additions for LDFLAGS if linking fails: -Xlinker --verbose 

DUMP=${RV_OBJDUMP}
COPY=${RV_OBJCOPY}

all: dhrystone.o dhrystone_main.bin

%.bin: %.elf
	$(COPY) -O binary $< $@

%.elf: %.o
	$(CC) $(CFLAGS) -o $@ crt0.s $< $(LDFLAGS) dhrystone.o

%.o: %.c *.h
	$(CC) $(CFLAGS) -c $<

dump: dhrystone_main.o
	$(DUMP) -d dhrystone_main.o

clean:
	rm -rf *.o *.elf *.bin
