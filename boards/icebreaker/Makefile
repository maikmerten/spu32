
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


top.json: top.v
	cd ../../software/asm && make
	cd ../.. && yosys -p 'read_verilog ./boards/icebreaker/top.v' -p 'synth_ice40 -dsp; write_json ./boards/icebreaker/top.json'

top.asc: top.json icebreaker.pcf
	nextpnr-ice40 --opt-timing --promote-logic --placer heap --randomize-seed --up5k --package sg48 --json top.json --pcf icebreaker.pcf --asc top.asc --freq 22 --timing-allow-fail --tmg-ripup

top.bin: top.asc
	icepack -s top.asc top.bin

prog_sram: top.bin
	iceprog -S top.bin

prog_flash: top.bin
	iceprog top.bin

config-local.vh: config-defaults.vh
	tail -n +8 config-defaults.vh > config-local.vh


clean:
	-rm top.json top.blif top.asc top.bin

.PHONY: prog_sram prog_flash reset_halt reset_boot clean

