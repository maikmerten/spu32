module prng_wb8(
        // naming according to Wisbhone B4 spec
        input[1:0] ADR_I,
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        output reg ACK_O,
        output reg[7:0] DAT_O
    );

    reg[31:0] state;

    always @(posedge CLK_I) begin
        ACK_O <= STB_I;
        if(STB_I) begin
            if(WE_I) begin
                case(ADR_I)
                    0: state[7:0] <= DAT_I;
                    1: state[15:8] <= DAT_I;
                    2: state[23:16] <= DAT_I;
                    default: state[31:24] <= DAT_I;
                endcase
            end else begin
                case(ADR_I)
                    0: DAT_O <= state[7:0];
                    1: DAT_O <= state[15:8];
                    2: DAT_O <= state[23:16];
                    default: begin
                        DAT_O <= state[31:24];
                        state <= {(((state[0] ^ state[10]) ^ state[30]) ^ state[31]), state[31:1]};
                    end
                endcase
            end
            
        end

    end


endmodule