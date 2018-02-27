`include "./spi/spicontroller.v"

module spicontroller_tb;

    `include "./tb/tbcommon.v"

    reg txstart, miso = 0;
    reg[7:0] txdata = 0;
    wire mosi, spiclk;
    wire[7:0] rxdata;


    spicontroller mut(
        .I_clk(clk),
        .I_tx_data(txdata),
        .I_tx_start(txstart),
        .I_spi_miso(miso),
        .O_spi_mosi(mosi),
        .O_spi_clk(spiclk),
        .O_rx_data(rxdata),
        .O_busy(busy)
    );

    initial begin
        $dumpfile("./spi/tests/spicontroller_tb.lxt");
		$dumpvars(0, clk, txdata, txstart, miso, mosi, spiclk, rxdata, busy, mut.risingclk, mut.fallingclk);

        #3
        txdata = 8'b10101011;
        txstart = 1;
        #1
        txstart = 0;


        #1000
        $finish;


    end


endmodule