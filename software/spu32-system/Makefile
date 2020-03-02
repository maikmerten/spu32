
SUBDIRS = libtinyc libspu32 boot-stage1 bios boot-stage2 shell apps

.PHONY: clean subdirs $(SUBDIRS)

all: stage1_stage2_bios.bin


stage1_stage2_bios.bin: subdirs
	cat boot-stage1/stage1_4k.bin boot-stage2/stage2_4k.bin bios/bios_32k.bin > bootbios.img

subdirs: $(SUBDIRS)

$(SUBDIRS):
	cd $@ && $(MAKE)

clean:
	rm -rf *.o *.elf *.bin *.img
