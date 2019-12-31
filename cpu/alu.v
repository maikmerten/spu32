`include "./cpu/aludefs.vh"

module spu32_cpu_alu(
        input I_clk,
        input I_en,
        input I_reset,
        input[31:0] I_dataS1,
        input[31:0] I_dataS2,
        input [3:0] I_aluop,
        output O_busy,
        output[31:0] O_data,
        output reg O_lt,
        output reg O_ltu,
        output reg O_eq
    );
    
    reg[31:0] result, sum, myor, myxor, myand;
    reg[32:0] sub; // additional bit for underflow detection
    reg eq, lt, ltu, busy = 0;
    reg[4:0] shiftcnt;

    assign O_data = result;

//`define SINGLE_CYCLE_SHIFTER
`ifdef SINGLE_CYCLE_SHIFTER
    wire[31:0] sll, srl, sra;
    wire signed[31:0] I_dataS1_signed;
    assign I_dataS1_signed[31:0] = I_dataS1[31:0];
    assign sll = (I_dataS1 << I_dataS2[4:0]);
    assign srl = (I_dataS1 >> I_dataS2[4:0]);
    assign sra = (I_dataS1_signed >>> I_dataS2[4:0]);
    assign O_busy = 0;
`else
    assign O_busy = busy;
`endif

    always @(*) begin
        sum = I_dataS1 + I_dataS2;
        sub = {1'b0, I_dataS1} - {1'b0, I_dataS2};
        
        myor = I_dataS1 | I_dataS2;
        myxor = I_dataS1 ^ I_dataS2;
        myand = I_dataS1 & I_dataS2;
    end
    
    always @(*) begin
        // unsigned comparison: simply look at underflow bit
        ltu = sub[32];
        // signed comparison: xor underflow bit with xored sign bit
        lt = (sub[32] ^ myxor[31]);
        
        eq = (sub[31:0] === 32'b0);
    end
    
    always @(posedge I_clk) begin
        if(I_reset) begin
            busy <= 0;
        end else if(I_en) begin
            case(I_aluop)
                default: result <= sum; // ALUOP_ADD
                `ALUOP_SUB: result <= sub[31:0];		
                `ALUOP_AND: result <= myand;
                `ALUOP_OR:  result <= myor;
                `ALUOP_XOR: result <= myxor;

                `ALUOP_SLT: begin
                    result <= 0;
                    if(lt) result[0] <= 1;
                end

                `ALUOP_SLTU: begin
                    result <= 0;
                    if(ltu) result[0] <= 1;
                end

                `ifndef SINGLE_CYCLE_SHIFTER
                // multi-cycle shifting, slow, but compact
                `ALUOP_SLL, `ALUOP_SRL, `ALUOP_SRA: begin
                    if(!busy) begin
                        busy <= 1;
                        result <= I_dataS1;
                        shiftcnt <= I_dataS2[4:0];
                    end else if(shiftcnt !== 5'b00000) begin
                        case(I_aluop)
                            `ALUOP_SLL: result <= {result[30:0], 1'b0};
                            `ALUOP_SRL: result <= {1'b0, result[31:1]};
                            default: result <= {result[31], result[31:1]};
                        endcase
                        shiftcnt <= shiftcnt - 5'd1;
                    end else begin
                        busy <= 0;
                    end
                end
                `else
                // single-cycle shifting
                `ALUOP_SLL: result <= sll;
                `ALUOP_SRA: result <= sra;
                `ALUOP_SRL: result <= srl;
                `endif
            endcase

            O_lt <= lt;
            O_ltu <= ltu;
            O_eq <= eq;

        end
    end

// --- FORMAL VERIFICATION --- //

`ifdef FORMAL

    function [31:0] trunc_33_to_32(input [32:0] val33);
        trunc_33_to_32 = val33[31:0];
    endfunction

    function signed[31:0] to_signed(input[31:0] val);
        to_signed[31:0] = val[31:0];
    endfunction

    always @(*) begin
        assert(sum == (I_dataS1 + I_dataS2));
        assert(sub[31:0] == (I_dataS1 - I_dataS2));
        assert(eq == (I_dataS1 == I_dataS2));
        assert(lt == (to_signed(I_dataS1)) < to_signed(I_dataS2));
        assert(ltu == (I_dataS1 < I_dataS2));

        if(I_dataS1 != I_dataS2) begin
            assert(sub[31:0] != 32'b0);
        end
    end

    reg past_valid = 1'b0;

    always @(posedge I_clk) begin
        past_valid <= 1;
        if(past_valid) begin

            if($past(I_en) && !$past(I_reset)) begin
                if($past(I_aluop) == `ALUOP_ADD) assert(O_data[31:0] == trunc_33_to_32($past(I_dataS1) + $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_SUB) assert(O_data[31:0] == trunc_33_to_32($past(I_dataS1) - $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_AND) assert(O_data[31:0] == ($past(I_dataS1) & $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_OR) assert(O_data[31:0] == ($past(I_dataS1) | $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_XOR) assert(O_data[31:0] == ($past(I_dataS1) ^ $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_SLT) begin
                    assert(O_data[0] == to_signed($past(I_dataS1)) < to_signed($past(I_dataS2)));
                    assert(O_data[31:1] == 31'b0);
                end
                if($past(I_aluop) == `ALUOP_SLTU) begin
                    assert(O_data[0] == $past(I_dataS1) < $past(I_dataS2));
                    assert(O_data[31:1] == 31'b0);
                end
            end

            if($past(I_reset)) begin
                assert(O_busy == 1'b0);
            end
        end
    end

`endif


endmodule
