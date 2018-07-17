
help:
	@echo
	@echo "make top.blif          run synthesis, generate BLIF netlist"
	@echo "make top.asc           run place and route, generate IceStorm ASCII file"
	@echo "make top.bin           run timing analysis, generate iCE40 BIN file"
	@echo
	@echo "make prog_sram         FPGA SRAM programming, (re)starts FPGA from SRAM"
	@echo "make prog_flash        serial flash programming"
	@echo
	@echo "make clean             remove output files"
	@echo

top.blif: top.v
	cd ../../software/asm && make
	cd ../.. && yosys -p 'synth_ice40 -blif ./boards/hx8k-breakout/top.blif' ./boards/hx8k-breakout/top.v

top.asc: top.blif hx8k-breakout.pcf
	arachne-pnr -r -d 8k -p hx8k-breakout.pcf -o top.asc top.blif

top.bin: top.asc
	icetime -d hx8k -c 42 top.asc
	icepack top.asc top.bin

prog_sram: top.bin
	iceprog -S top.bin

prog_flash: top.bin
	iceprog top.bin


clean:
	-rm top.blif top.asc top.bin

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

