`include "./uart/uart_wb8.v"

module uart_wb8_tb;

    `include "./tb/tbcommon.v"

    reg[1:0] adr = 0;
    reg[7:0] dat_i = 8'b01010100;
    reg stb, rx, we = 0;
    wire tx, ack;
    wire[7:0] dat_o;

    uart_wb8 mut(
        .ADR_I(adr),
        .CLK_I(clk),
        .DAT_I(dat_i),
        .STB_I(stb),
        .WE_I(we),
        .DAT_O(dat_o),
        .ACK_O(ack),
        .I_rx(rx),
        .O_tx(tx)
    );

    initial begin
        $dumpfile("./uart/tests/uart_wb8_tb.lxt");
		$dumpvars(0, adr, clk, dat_i, stb, we, dat_o, ack, rx, tx);

        #3
        we = 1;
        stb = 1;
        #2
        we = 0;
        stb = 0;
      

        #99999
        $finish;
    end


endmodule