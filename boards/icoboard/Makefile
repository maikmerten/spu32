
ifeq ($(shell bash -c 'type -p icoprog'),)
SSH_RASPI ?= ssh pi@fpgapi.local
else
SSH_RASPI ?= sh -c
endif

help:
	@echo
	@echo "make top.blif          run synthesis, generate BLIF netlist"
	@echo "make top.asc           run place and route, generate IceStorm ASCII file"
	@echo "make top.bin           run timing analysis, generate iCE40 BIN file"
	@echo
	@echo "make prog_sram         FPGA SRAM programming, (re)starts FPGA from SRAM"
	@echo "make prog_flash        serial flash programming, does not touch FPGA"
	@echo "make prog_erase        erase first flash block"
	@echo
	@echo "make reset_halt        stop FPGA and keep in reset"
	@echo "make reset_boot        (re)start FPGA from serial flash"
	@echo
	@echo "make clean             remove output files"
	@echo

top.blif: top.v
	cd ../.. && yosys -p 'synth_ice40 -blif ./boards/icoboard/top.blif' ./boards/icoboard/top.v

top.asc: top.blif icoboard.pcf
	arachne-pnr -d 8k -p icoboard.pcf -o top.asc top.blif

top.bin: top.asc
	icetime -d hx8k -c 25 top.asc
	icepack top.asc top.bin

prog_sram: top.bin
	$(SSH_RASPI) 'icoprog -p' < top.bin

prog_flash: top.bin
	$(SSH_RASPI) 'icoprog -f' < top.bin

prog_erase:
	$(SSH_RASPI) 'icoprog -e'

reset_halt:
	$(SSH_RASPI) 'icoprog -R'

reset_boot:
	$(SSH_RASPI) 'icoprog -b'

clean:
	rm top.blif top.asc top.bin

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

