`include "./cpu/cpu.v"
`include "./ram/bram_wb8.v"
`include "./leds/leds_wb8.v"

module cpu_tb();

    `include "./tb/tbcommon.v"

    reg reset = 1;
    reg interrupt = 0;

    wire cpu_cyc, cpu_stb, cpu_we;
    wire[7:0] cpu_dat;
    wire[31:0] cpu_adr;

    reg[7:0] arbiter_dat_o;
    reg arbiter_ack_o;

    cpu cpu_inst(
        .CLK_I(clk),
	    .ACK_I(arbiter_ack_o),
	    .DAT_I(arbiter_dat_o),
	    .RST_I(reset),
        .INTERRUPT_I(interrupt),
	    .ADR_O(cpu_adr),
	    .DAT_O(cpu_dat),
	    .CYC_O(cpu_cyc),
	    .STB_O(cpu_stb),
	    .WE_O(cpu_we)
    );

    wire ram_ack;
    reg ram_stb;
    wire[7:0] ram_dat;

    bram_wb8 #(
        .RAMINITFILE("./cpu/tests/testgen/testsuite.dat")
    ) ram_inst (
	    .CLK_I(clk),
	    .STB_I(ram_stb),
	    .WE_I(cpu_we),
	    .ADR_I(cpu_adr[9:0]),
	    .DAT_I(cpu_dat),
	    .DAT_O(ram_dat),
	    .ACK_O(ram_ack)
    );

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    leds_wb8 leds_inst(
        .CLK_I(clk),
        .DAT_I(cpu_dat),
        .STB_I(leds_stb),
        .WE_I(cpu_we),
        .DAT_O(leds_dat),
        .ACK_O(leds_ack),
        .O_leds(leds_value)
    );

    // bus arbiter
    always @(*) begin
        ram_stb = 0;
        leds_stb = 0;

        case(cpu_adr[31:28])
            4'hF: begin
                arbiter_dat_o = leds_dat;
                arbiter_ack_o = leds_ack;
                leds_stb = cpu_stb;
            end

            default: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end
        endcase

    end


    initial begin
        $dumpfile("./cpu/tests/cpu_tb.lxt");
		$dumpvars(0, clk, error, reset, cpu_cyc, cpu_stb, cpu_we, cpu_dat, cpu_adr, ram_ack, ram_dat, cpu_inst.state, cpu_inst.busy, cpu_inst.alu_en, cpu_inst.alu_op, cpu_inst.bus_en, cpu_inst.bus_op, cpu_inst.reg_re, cpu_inst.reg_we, cpu_inst.bus_addr, cpu_inst.alu_dataout, cpu_inst.reg_val1, cpu_inst.reg_val2, cpu_inst.dec_rs1, cpu_inst.dec_rs2, cpu_inst.dec_rd, cpu_inst.reg_datain, cpu_inst.bus_dataout, leds_value);

        #3
        reset = 0;

        @(leds_value == 8'hF0)
        #128

        if(leds_value === 8'hFF) begin
            $display("VERDICT: PASS   \\o/");
        end else begin
            $display("VERDICT: !!! FAIL !!!, failed testcase %d", leds_value);
            $finish_and_return(1);
        end
        $finish;

    end

    reg[31:0] clkcount = 0;

    // make sure we don't end up in an endless loop
    always @(posedge clk) begin
        clkcount = clkcount + 1;
        if(clkcount > 99999) begin
            $display("TEST TIMED OUT!");
            $finish_and_return(1);
        end
    end


endmodule