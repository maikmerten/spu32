`include "./cpu/cpu.v"
`define RAMINITFILE "./cpu/tests/testgen/testsuite.dat"
`include "./ram/ram1k_wb8.v"

module cpu_tb();

    `include "./tb/tbcommon.v"

    reg reset = 1;

    wire cpu_cyc, cpu_stb, cpu_we;
    wire[7:0] cpu_dat;
    wire[31:0] cpu_adr;

    wire ram_ack;
    wire[7:0] ram_dat;

    cpu cpu_inst(
        .CLK_I(clk),
	    .ACK_I(ram_ack),
	    .DAT_I(ram_dat),
	    .RST_I(reset),
	    .ADR_O(cpu_adr),
	    .DAT_O(cpu_dat),
	    .CYC_O(cpu_cyc),
	    .STB_O(cpu_stb),
	    .WE_O(cpu_we)
    );

    ram1k_wb8 ram_inst(
	    .CLK_I(clk),
	    .STB_I(cpu_stb),
	    .WE_I(cpu_we),
	    .ADR_I(cpu_adr[9:0]),
	    .DAT_I(cpu_dat),
	    .DAT_O(ram_dat),
	    .ACK_O(ram_ack)
    );

    initial begin
        $dumpfile("./cpu/tests/cpu_tb.lxt");
		$dumpvars(0, clk, error, reset, cpu_cyc, cpu_stb, cpu_we, cpu_dat, cpu_adr, ram_ack, ram_dat, cpu_inst.state, cpu_inst.busy, cpu_inst.alu_en, cpu_inst.bus_en, cpu_inst.reg_re, cpu_inst.reg_we, cpu_inst.bus_addr, cpu_inst.alu_dataout, cpu_inst.reg_val1, cpu_inst.reg_val2, cpu_inst.dec_rs1, cpu_inst.dec_rs2, cpu_inst.dec_rd, cpu_inst.reg_datain, cpu_inst.bus_dataout);



        #3
        reset = 0;

        #8192
        if(cpu_dat === 8'hFF) begin
            $display("VERDICT: PASS   \\o/");
        end else begin
            $display("VERDICT: !!! FAIL !!!, failed testcase %d", cpu_dat);
            $finish_and_return(1);
        end
        $finish;

    end


endmodule