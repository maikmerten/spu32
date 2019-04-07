
help:
	@echo
	@echo "make top.json          run synthesis, generate JSON netlist"
	@echo "make top.asc           run place and route, generate IceStorm ASCII file"
	@echo "make top.bin           run timing analysis, generate iCE40 BIN file"
	@echo
	@echo "make prog_sram         FPGA SRAM programming, (re)starts FPGA from SRAM"
	@echo "make prog_flash        serial flash programming"
	@echo
	@echo "make clean             remove output files"
	@echo

EXECS = yosys nextpnr-ice40 icepack iceprog
CHECK := $(foreach exec,$(EXECS),\
    $(if $(shell which $(exec)),some string,$(error "No $(exec) in PATH. yosys, icestorm and nextpnr are needed)))


top.json: config-local.vh top.v
	cd ../../software/asm && make
	cd ../.. && yosys -p 'synth_ice40 -json ./boards/hx8k-breakout/top.json' ./boards/hx8k-breakout/top.v

top.asc: top.json hx8k-breakout.pcf
	nextpnr-ice40 --randomize-seed --placer heap --hx8k --json top.json --pcf hx8k-breakout.pcf --asc top.asc --freq 28

top.bin: top.asc
	icepack top.asc top.bin

prog_sram: top.bin
	iceprog -S top.bin

prog_flash: top.bin
	iceprog top.bin

config-local.vh: config-defaults.vh
	tail -n +8 config-defaults.vh > config-local.vh


clean:
	-rm top.json top.blif top.asc top.bin

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

