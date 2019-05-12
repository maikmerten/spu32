`include "./spi/spi_wb8.v"

module spi_wb8_tb;

    `include "./tb/tbcommon.v"

    reg[1:0] adr = 0;
    reg[7:0] dat_i = 8'b01010100;
    reg stb, rx, we = 0;
    wire tx, ack;
    wire[7:0] dat_o;

    reg spi_miso = 0;
    wire spi_clk, spi_mosi, spi_cs;

    spi_wb8 mut(
        .I_wb_adr(adr),
        .I_wb_clk(clk),
        .I_wb_dat(dat_i),
        .I_wb_stb(stb),
        .I_wb_we(we),
        .O_wb_dat(dat_o),
        .O_wb_ack(ack),
        // SPI signals
        .I_spi_miso(spi_miso),
        .O_spi_clk(spi_clk),
        .O_spi_mosi(spi_mosi),
        .O_spi_cs(spi_cs)
    );

    initial begin
        $dumpfile("./spi/tests/spi_wb8_tb.lxt");
		$dumpvars(0, adr, clk, dat_i, stb, we, dat_o, ack, spi_miso, spi_mosi, spi_clk, spi_cs, mut.state);

        #2
        we = 1;
        stb = 1;
        #4
        we = 0;
        stb = 0;
      

        #9999
        $finish;
    end


endmodule