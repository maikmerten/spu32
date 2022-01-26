`default_nettype none

module ice40_spram_1mbit_wb32
	(
		input I_wb_clk,
		input I_wb_stb,
		input I_wb_we,
		input[14:0] I_wb_adr,
        input[3:0] I_wb_sel,
		input[31:0] I_wb_dat,
		output[31:0] O_wb_dat,
		output reg O_wb_ack
	);

    wire write = (I_wb_stb & I_wb_we);


    wire[15:0] data0, data1, data2, data3;
    reg[31:0] readbuf;
    assign O_wb_dat = readbuf;

    always @(negedge I_wb_clk) begin
        // register SPRAM output
        if(I_wb_stb) begin
            case(I_wb_adr[14])
                1'b0: readbuf <= {data1, data0};
                1'b1: readbuf <= {data3, data2};
            endcase
        end
    end

    wire bank0_cs = !I_wb_adr[14];
    wire bank1_cs = I_wb_adr[14];

    SB_SPRAM256KA ram00 (
        .ADDRESS(I_wb_adr[13:0]),
        .DATAIN(I_wb_dat[15:0]),
        .MASKWREN({I_wb_sel[1], I_wb_sel[1], I_wb_sel[0], I_wb_sel[0]}),
        .WREN(write),
        .CHIPSELECT(bank0_cs),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data0)
    );

    SB_SPRAM256KA ram01 (
        .ADDRESS(I_wb_adr[13:0]),
        .DATAIN(I_wb_dat[31:16]),
        .MASKWREN({I_wb_sel[3], I_wb_sel[3], I_wb_sel[2], I_wb_sel[2]}),
        .WREN(write),
        .CHIPSELECT(bank0_cs),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data1)
    );

    SB_SPRAM256KA ram10 (
        .ADDRESS(I_wb_adr[13:0]),
        .DATAIN(I_wb_dat[15:0]),
        .MASKWREN({I_wb_sel[1], I_wb_sel[1], I_wb_sel[0], I_wb_sel[0]}),
        .WREN(write),
        .CHIPSELECT(bank1_cs),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data2)
    );

    SB_SPRAM256KA ram11 (
        .ADDRESS(I_wb_adr[13:0]),
        .DATAIN(I_wb_dat[31:16]),
        .MASKWREN({I_wb_sel[3], I_wb_sel[3], I_wb_sel[2], I_wb_sel[2]}),
        .WREN(write),
        .CHIPSELECT(bank1_cs),
        .CLOCK(I_wb_clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(data3)
    );


    always @(posedge I_wb_clk) begin
		O_wb_ack <= I_wb_stb;
	end

endmodule