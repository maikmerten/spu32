`default_nettype none

`include "./bus/wishbone32.v"
`include "./ram/bram_wb32.v"

module wishbone32_tb;

    `include "./tb/tbcommon.v"

    reg cpu_strobe, cpu_write, cpu_halfword, cpu_fullword = 0;
    reg[31:0] cpu_addr = 0;
    reg[31:0] cpu_data = 0;
    wire[31:0] mut_data;
    wire mut_wait;
    wire ram_ack;
    wire[31:0] ram_data;
    reg cpu_reset = 1'b0;
    wire[29:0] bus_addr;
    wire[31:0] bus_data;
    wire bus_cyc, bus_stb, bus_we;
    wire[3:0] bus_sel;


    spu32_bus_wishbone32 mut(
        .I_clk(clk),
        .I_reset(cpu_reset),
        // signals to CPU bus
        .I_strobe(cpu_strobe),
        .I_write(cpu_write),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .I_addr(cpu_addr),
        .I_data(cpu_data),
        .O_data(mut_data),
        .O_wait(mut_wait),
        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        .I_wb_ack(ram_ack),
        .I_wb_stall(1'b0),
        .I_wb_dat(ram_data),
        .O_wb_adr(bus_addr),
        .O_wb_dat(bus_data),
        .O_wb_cyc(bus_cyc),
        .O_wb_stb(bus_stb),
        .O_wb_we(bus_we),
        .O_wb_sel(bus_sel)// byte enables
    );

    bram_wb32 tb_ram (
		.I_wb_clk(clk),
		.I_wb_stb(bus_stb),
		.I_wb_we(bus_we),
		.I_wb_adr(bus_addr[10:0]),
		.I_wb_dat(bus_data),
        .I_wb_sel(bus_sel),
		.O_wb_dat(ram_data),
		.O_wb_ack(ram_ack)
	);



    initial begin
        $dumpfile("wishbone32_tb.lxt");
        $dumpvars(0, wishbone32_tb);


        cpu_reset = 1;
        #4;
        cpu_reset = 0;
        #2;

        cpu_addr = 0;
        cpu_strobe = 1;
        cpu_data = 32'h87654321;
        cpu_halfword = 0;
        cpu_fullword = 1;
        cpu_write = 1;

        @(negedge mut_wait) // wait for write to finish
        cpu_addr = 4;
        cpu_data = 32'hddccbbaa;

        @(negedge mut_wait) // wait for write to finish
        // read between words
        cpu_addr = 2;
        cpu_write = 0;

        @(negedge mut_wait) // wait for read to finish
        if(mut_data != 32'hbbaa8765) error = 1;

        // single byte-write
        cpu_halfword = 0;
        cpu_fullword = 0;
        cpu_data = 32'hffffffff;
        cpu_addr = 4;
        cpu_write = 1;

        @(negedge mut_wait) // wait for write to finish

        // read word
        cpu_write = 0;
        cpu_halfword = 0;
        cpu_fullword = 0;

        @(negedge mut_wait) // wait for read to finish
        if(mut_data != 32'hddccbbff) error = 2;


        #4
        $finish;
    end


endmodule