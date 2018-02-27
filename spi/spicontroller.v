module spicontroller(
        input I_clk,
        input[7:0] I_tx_data,
        input I_tx_start,
        input I_spi_miso,
        output O_spi_mosi,
        output reg O_spi_clk,
        output[7:0] O_rx_data,
        output O_busy
    );

    reg[7:0] txbuffer, rxbuffer;

    reg busy = 0;
    reg[1:0] clkcounter = 0;
    reg spiclk, lastspiclk, risingclk, fallingclk;

    reg[3:0] bitcounter = 0;

    localparam STATE_IDLE = 0;
    localparam STATE_ACTIVE = 1;
    reg state = STATE_IDLE;


    always @(posedge I_clk) begin
        lastspiclk <= spiclk;
        clkcounter <= clkcounter + 1;
        spiclk <= clkcounter[1];

        risingclk <= (lastspiclk == 0) && (spiclk == 1);
        fallingclk <= (lastspiclk == 1) && (spiclk == 0);

        if(I_tx_start) busy <= 1;

        case(state)
            STATE_IDLE: begin
                O_spi_clk <= 0;
                txbuffer <= 8'h00;

                if(busy && fallingclk) begin
                    bitcounter <= 8;
                    txbuffer <= I_tx_data;
                    state <= STATE_ACTIVE;
                end
        
            end
        
            STATE_ACTIVE: begin
                O_spi_clk <= spiclk;

                // shift data in on rising edge
                if(risingclk) begin
                    rxbuffer <= {rxbuffer[6:0], I_spi_miso};
                    bitcounter <= bitcounter - 1;
                end

                // shift data out on falling edge
                if(fallingclk) begin
                    txbuffer <= {txbuffer[6:0], 1'b0};
                    if(bitcounter == 0) begin
                        state <= STATE_IDLE;
                        busy <= 0;
                    end
                end

            end
        endcase
    end

    assign O_spi_mosi = txbuffer[7];
    assign O_rx_data = rxbuffer;
    assign O_busy = busy;



endmodule