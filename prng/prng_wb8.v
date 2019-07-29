module prng_wb8(
        // Wishbone signals
        input[1:0] I_wb_adr,
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat
    );

    reg[31:0] state;

    always @(posedge I_wb_clk) begin
        O_wb_ack <= I_wb_stb;
        if(I_wb_stb) begin
            if(I_wb_we) begin
                case(I_wb_adr)
                    0: state[7:0] <= I_wb_dat;
                    1: state[15:8] <= I_wb_dat;
                    2: state[23:16] <= I_wb_dat;
                    default: state[31:24] <= I_wb_dat;
                endcase
            end else begin
                case(I_wb_adr)
                    0: O_wb_dat <= state[7:0];
                    1: O_wb_dat <= state[15:8];
                    2: O_wb_dat <= state[23:16];
                    default: begin
                        O_wb_dat <= state[31:24];
                        state <= {(((state[0] ^ state[10]) ^ state[30]) ^ state[31]), state[31:1]};
                    end
                endcase
            end
        end
    end


endmodule