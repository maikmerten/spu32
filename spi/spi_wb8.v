`include "./spi/spicontroller.v"

module spi_wb8(
        // Wishbone signals
        input CLK_I,
        input STB_I,
        input WE_I,
        input[1:0] ADR_I,
        input[7:0] DAT_I,
        output reg [7:0] DAT_O,
        output reg ACK_O,

        // SPI signals
        input I_spi_miso,
        output O_spi_clk,
        output O_spi_mosi,
        output O_spi_cs
    );


    reg cs = 0;
    assign O_spi_cs = !cs; // chip select is active low

    reg txstart = 0;
    reg[7:0] txdata = 0;
    wire[7:0] rxdata;
    wire busy;

    spicontroller spictrl(
        .I_clk(CLK_I),
        .I_tx_data(txdata),
        .I_tx_start(txstart),
        .I_spi_miso(I_spi_miso),
        .O_spi_mosi(O_spi_mosi),
        .O_spi_clk(O_spi_clk),
        .O_rx_data(rxdata),
        .O_busy(busy)
    );

    localparam STATE_IDLE = 0;
    localparam STATE_WAIT_BUSY = 1;
    localparam STATE_WAIT_READY = 2;
    reg[1:0] state = STATE_IDLE;

   	always @(posedge CLK_I) begin
		ACK_O <= 0;
		if(STB_I) begin
            ACK_O <= 1;

            case(ADR_I)
                0: begin
                    if(WE_I) begin
                        if(state == STATE_IDLE) begin
                            txdata <= DAT_I;
                            state <= STATE_WAIT_BUSY;
                        end
                    end else begin
                        DAT_O <= rxdata;
                    end
                end

                1: begin // chip select
                    if(WE_I) cs <= DAT_I[0];
                    else DAT_O <= {7'b0, cs};
                end

                default: begin // ready signal
                    DAT_O <= {7'b0, (state == STATE_IDLE ? 1'b1 : 1'b0)};
                end

            endcase

            // if not idle, a transmission is in progress. Ensure it proceeds orderly
            case(state)
                STATE_WAIT_BUSY: begin
                    // tell SPI controller to start transmission until it asserts busy
                    txstart <= 1;
                    if(busy) state <= STATE_WAIT_READY;
                end

                STATE_WAIT_READY: begin
                    // wait for SPI controller to deassert busy, which means it should be finished
                    txstart <= 0;
                    if(!busy) state <= STATE_IDLE;
                end

                default: begin end
            endcase

        end

	end

endmodule