`include "./spi/spicontroller.v"

module spi_wb8(
        // Wishbone signals
        input I_wb_clk,
        input I_wb_stb,
        input I_wb_we,
        input[1:0] I_wb_adr,
        input[7:0] I_wb_dat,
        output reg [7:0] O_wb_dat,
        output reg O_wb_ack,

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
        .I_clk(I_wb_clk),
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

   	always @(posedge I_wb_clk) begin
		O_wb_ack <= I_wb_stb;
		if(I_wb_stb) begin

            case(I_wb_adr)
                0: begin
                    if(I_wb_we) begin
                        if(state == STATE_IDLE) begin
                            txdata <= I_wb_dat;
                            state <= STATE_WAIT_BUSY;
                        end
                    end else begin
                        O_wb_dat <= rxdata;
                    end
                end

                1: begin // chip select
                    if(I_wb_we) cs <= I_wb_dat[0];
                    else O_wb_dat <= {7'b0, cs};
                end

                default: begin // ready signal
                    O_wb_dat <= {7'b0, (state == STATE_IDLE ? 1'b1 : 1'b0)};
                end

            endcase

        end

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

endmodule