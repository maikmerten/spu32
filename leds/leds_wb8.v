module leds_wb8(
        // Wishbone signals
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat,
        // reset signal
        input I_reset,
        // output for LEDS
        output[7:0] O_leds
    );

    reg[7:0] ledvalue = 0;
    assign O_leds = ledvalue;

    always @(posedge I_wb_clk) begin
        if(I_wb_stb) begin
            if(I_wb_we) begin
                ledvalue <= I_wb_dat;
            end
            O_wb_dat <= ledvalue;
        end
        O_wb_ack <= I_wb_stb;

        if(I_reset) ledvalue <= 0;

    end


endmodule