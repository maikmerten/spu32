`include "./cpu/busdefs.vh"
`include "./cpu/bus_wb8.v"
`include "./ram/bram_wb8.v"

module bus_wb8_tb;

    `include "./tb/tbcommon.v"


    reg reset = 0;
    reg en = 0;
    reg[2:0] op = 0;
    reg[31:0] addr = 0, datain = 0;
    wire[31:0] dataout;
    wire busy;

    wire[31:0] bus_addr;
    wire[7:0] bus_dat;
    wire bus_cyc, bus_stb, bus_we;

    wire[7:0] ram_dat;
    wire ram_ack;

    wire stall = 0;

    spu32_cpu_bus_wb8 mut(
        .I_en(en),
        .I_op(op),
        .I_addr(addr),
        .I_data(datain),
        .O_data(dataout),
        .O_busy(busy),

        .CLK_I(clk),
        .ACK_I(ram_ack),
        .STALL_I(stall),
        .DAT_I(ram_dat),
        .RST_I(reset),
        .ADR_O(bus_addr),
        .DAT_O(bus_dat),
        .CYC_O(bus_cyc),
        .STB_O(bus_stb),
        .WE_O(bus_we)
    );


    bram_wb8 #(
        .RAMINITFILE("./cpu/tests/bus_wb8_tb_raminit.dat")
    ) ram (
        .I_wb_clk(clk),
        .I_wb_stb(bus_stb),
        .I_wb_we(bus_we),
        .I_wb_adr(bus_addr[12:0]),
        .I_wb_dat(bus_dat),
        .O_wb_dat(ram_dat),
        .O_wb_ack(ram_ack)
    );

    initial begin
        $dumpfile("./cpu/tests/bus_wb8_tb.lxt");
        $dumpvars(0, error, reset, clk, en, op, addr, datain, dataout, busy, bus_addr, bus_dat, bus_cyc, bus_stb, bus_we, ram_dat, ram_ack);

        #1
        @(negedge clk)
        reset = 1;
        #4
        reset = 0;

        @(negedge clk)


        en = 1;
        addr = 0;
        op = `BUSOP_READB;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h0) error = 1;

        addr = 1;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h1) error = 2;

        addr = 2;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h2) error = 3;

        addr = 3;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h3) error = 4;



        addr = 0;
        op = `BUSOP_READBU;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h0) error = 5;

        addr = 1;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h1) error = 6;

        addr = 2;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h2) error = 7;

        addr = 3;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h3) error = 8;



        addr = 4;
        op = `BUSOP_READB;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'hFFFFFF80) error = 9;

        addr = 5;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'hFFFFFF81) error = 10;

        addr = 6;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'hFFFFFF82) error = 11;

        addr = 7;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'hFFFFFF83) error = 12;


        
        addr = 4;
        op = `BUSOP_READBU;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h80) error = 13;

        addr = 5;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h81) error = 14;

        addr = 6;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h82) error = 15;

        addr = 7;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h83) error = 16;


        addr = 0;
        op = `BUSOP_READH;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h00000100) error = 17;

        addr = 3;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'hFFFF8003) error = 18;



        addr = 0;
        op = `BUSOP_READHU;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h00000100) error = 19;

        addr = 3;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h00008003) error = 20;


        addr = 2;
        op = `BUSOP_READW;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h81800302) error = 21;


        addr = 1;
        op = `BUSOP_READW;
        @(negedge busy)
        @(negedge clk)
        if(dataout !== 32'h80030201) error = 22;


        datain = 32'hCAFEBEEF;
        addr = 0;
        op = `BUSOP_WRITEB;
        @(negedge busy)
        @(negedge clk);
        op = `BUSOP_READW;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h030201EF) error = 23;

        op = `BUSOP_WRITEH;
        @(negedge busy)
        @(negedge clk);
        op = `BUSOP_READW;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'h0302BEEF) error = 24;

        op = `BUSOP_WRITEW;
        @(negedge busy)
        @(negedge clk);
        op = `BUSOP_READW;
        @(negedge busy)
        @(negedge clk)
        if(dataout != 32'hCAFEBEEF) error = 25;


        #1

        $finish;

    end


endmodule
