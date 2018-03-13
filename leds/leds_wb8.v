module leds_wb8(
        // naming according to Wisbhone B4 spec
        // input[31:0] ADR_I, no address needed here, only one memory location
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        output reg ACK_O,
        output reg[7:0] DAT_O,
        // output for LEDS
        output[7:0] O_leds
    );

    reg[7:0] ledvalue = 0;
    assign O_leds = ledvalue;

    always @(posedge CLK_I) begin
        ACK_O <= 0;
        if(STB_I) begin
            if(WE_I) begin
                ledvalue <= DAT_I;
            end else begin
                DAT_O <= ledvalue;
            end
            ACK_O <= 1;
        end

    end


endmodule