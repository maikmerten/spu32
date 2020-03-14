
SUBDIRS = libtinyc libspu32 boot-stage1 bios boot-stage2 shell apps
SUBDIRSCLEAN=$(addsuffix .clean,$(SUBDIRS))

.PHONY: clean subdirs $(SUBDIRS) subdirsclean $(SUBDIRSCLEAN)

all: stage1_stage2_bios.bin

$(SUBDIRS):
	cd $@ && $(MAKE)

$(SUBDIRSCLEAN):
	cd $(basename $@) && $(MAKE) clean


subdirs: $(SUBDIRS)

subdirsclean: $(SUBDIRSCLEAN)

stage1_stage2_bios.bin: subdirs
	cat boot-stage1/stage1_4k.bin boot-stage2/stage2_4k.bin bios/bios_32k.bin > bootbios.img


clean: subdirsclean
	rm -rf *.o *.elf *.bin *.img
