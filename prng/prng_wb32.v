module prng_wb32(
        // Wishbone signals
        input I_wb_clk,
        input[3:0] I_wb_sel,
        input[31:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[31:0] O_wb_dat
    );

    reg[31:0] state;
    wire write = I_wb_we & (I_wb_sel == 4'b1111);

    always @(posedge I_wb_clk) begin
        O_wb_ack <= I_wb_stb;
        if(I_wb_stb) begin
            if(write) begin
                state <= I_wb_dat;
            end else begin
                O_wb_dat <= state;
                state <= {(((state[0] ^ state[10]) ^ state[30]) ^ state[31]), state[31:1]};
            end
        end
    end


endmodule