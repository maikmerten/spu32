`default_nettype none

module ice40_spram_1mbit_wb8_vga
	(
		input I_wb_clk,
		input I_wb_stb,
		input I_wb_we,
		input[16:0] I_wb_adr,
		input[7:0] I_wb_dat,
		output[7:0] O_wb_dat,
		output reg O_wb_ack,
        output O_wb_stall,
        input I_vga_req,
        input[15:0] I_vga_adr,
        output[15:0] O_vga_dat
	);

    wire[16:0] addr = I_vga_req ? {I_vga_adr, 1'b0} : I_wb_adr;

    assign O_wb_stall = I_wb_stb & I_vga_req;
	wire write = (I_wb_stb & I_wb_we & !I_vga_req);

    reg unaligned;
    reg[1:0] bank;

    wire[15:0] writedata = {I_wb_dat, I_wb_dat};
    wire[3:0] wemask = {I_wb_adr[0], I_wb_adr[0], !I_wb_adr[0], !I_wb_adr[0]};

    wire[15:0] data0, data1, data2, data3;
    reg[15:0] reg_data0, reg_data1, reg_data2, reg_data3;

    always @(negedge I_wb_clk) begin
        // register SPRAM output
        reg_data0 <= data0;
        reg_data1 <= data1;
        reg_data2 <= data2;
        reg_data3 <= data3;
    end

    reg[15:0] readdata;
    always @(*) begin
        case(bank)
            2'b00: readdata = reg_data0;
            2'b01: readdata = reg_data1;
            2'b10: readdata = reg_data2;
            2'b11: readdata = reg_data3;
        endcase
    end
    assign O_wb_dat = unaligned ? readdata[15:8] : readdata[7:0];
    assign O_vga_dat = {readdata[7:0], readdata[15:8]};


    reg[3:0] cs;
    always @(*) begin
        cs = 4'b0000;
        cs[addr[2:1]] = I_wb_stb | I_vga_req;
    end

    SB_SPRAM256KA ram00 (
        .ADDRESS(addr[16:3]),
        .DATAIN(writedata),
        .MASKWREN(wemask),
        .WREN(write),
        .CHIPSELECT(cs[0]),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data0)
    );

    SB_SPRAM256KA ram01 (
        .ADDRESS(addr[16:3]),
        .DATAIN(writedata),
        .MASKWREN(wemask),
        .WREN(write),
        .CHIPSELECT(cs[1]),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data1)
    );

    SB_SPRAM256KA ram10 (
        .ADDRESS(addr[16:3]),
        .DATAIN(writedata),
        .MASKWREN(wemask),
        .WREN(write),
        .CHIPSELECT(cs[2]),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data2)
    );

    SB_SPRAM256KA ram11 (
        .ADDRESS(addr[16:3]),
        .DATAIN(writedata),
        .MASKWREN(wemask),
        .WREN(write),
        .CHIPSELECT(cs[3]),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data3)
    );


    always @(posedge I_wb_clk) begin
        bank <= addr[2:1];
        unaligned <= addr[0];
		O_wb_ack <= I_wb_stb & !I_vga_req; //FIXME - this crashes the CPU
	end

endmodule