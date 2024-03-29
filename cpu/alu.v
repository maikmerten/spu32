`default_nettype none

`ifdef FORMAL
    // There are other files included with their own formal verification setup.
    // Define ALUFORMAL to skip their respective formal verification code - their assertions
    // won't hold with the assumptions made for ALU formal verification.
    `define ALUFORMAL
`endif


`include "./cpu/aludefs.vh"
`include "./cpu/mul.v"
`include "./cpu/muldsp.v"
`include "./cpu/shifter.v"
`include "./cpu/div.v"


module spu32_cpu_alu
    #(
        parameter MULDSP = 0
    )
    (
        input I_clk,
        input I_en,
        input I_reset,
        input[31:0] I_dataS1,
        input[31:0] I_dataS2,
        input[3:0] I_aluop,
        input[1:0] I_aluop_signed,
        output O_busy,
        output[31:0] O_data,
        output[31:0] O_loadstore_adr,
        output O_lt,
        output O_ltu,
        output O_eq
    );
   
    reg[31:0] result, sum, myor, myxor, myand;
    reg[32:0] sub; // additional bit for underflow detection
    reg eq, lt, ltu, busy = 0;
    reg[4:0] shiftcnt;

    assign O_data = result;
    assign O_lt = lt;
    assign O_ltu = ltu;
    assign O_eq = eq;
    assign O_loadstore_adr = sum;

    wire[63:0] mul_result;
    wire mul_busy;
    // multiplication unit

    if(MULDSP) begin
        // single-cycle shifter using DSP blocks
        spu32_cpu_muldsp mul_inst(
            .I_clk(I_clk),
            .I_en(I_en),
            .I_op(I_aluop),
            .I_op_signed(I_aluop_signed),
            .I_reset(I_reset),
            .I_s1(I_dataS1),
            .I_s2(I_dataS2),
            .O_result(mul_result),
            .O_busy(mul_busy)
        );
    end else begin
        // multi-cycle shifter without DSP blocks
        spu32_cpu_mul mul_inst(
            .I_clk(I_clk),
            .I_en(I_en),
            .I_op(I_aluop),
            .I_op_signed(I_aluop_signed),
            .I_reset(I_reset),
            .I_s1(I_dataS1),
            .I_s2(I_dataS2),
            .O_result(mul_result),
            .O_busy(mul_busy)
        );
    end

    wire[31:0] div_result;
    wire div_busy;
    wire op_div = I_aluop == `ALUOP_DIV;
    wire op_rem = I_aluop == `ALUOP_REM;
    spu32_cpu_div div_inst(
        .I_clk(I_clk),
        .I_en(I_en & (op_div | op_rem)),
        .I_dividend(I_dataS1),
        .I_divisor(I_dataS2),
        .I_divide(op_div),
        .I_signed_op(I_aluop_signed[0] || I_aluop_signed[1]),
        .I_reset(I_reset),
        .O_result(div_result),
        .O_busy(div_busy)
    );

    wire zeros31 = {31{1'b0}};


`define SINGLE_CYCLE_SHIFTER
`ifdef SINGLE_CYCLE_SHIFTER
    wire[31:0] shifter_out;
    wire leftshift = (I_aluop == `ALUOP_SLL);
    wire signextend = (I_aluop == `ALUOP_SRA);
    spu32_cpu_shifter spu32_cpu_shifter_inst(
        .I_data(I_dataS1),
        .I_shift(I_dataS2[4:0]),
        .I_leftshift(leftshift),
        .I_signextend(signextend),
        .O_data(shifter_out)
    );

    assign O_busy = (mul_busy || div_busy);
`else
    assign O_busy = (busy || mul_busy || div_busy);
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
        eq = I_dataS1 === I_dataS2;
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
                `ALUOP_SLT: result <= { {31{1'b0}}, lt};
                `ALUOP_SLTU: result <= { {31{1'b0}}, ltu};


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
                `ALUOP_SLL, `ALUOP_SRA, `ALUOP_SRL: result <= shifter_out;
                `endif

                `ALUOP_MUL: result <= mul_result[31:0];
                `ALUOP_MULH: result <= mul_result[63:32];

                `ALUOP_DIV, `ALUOP_REM: result <= div_result;

            endcase

        end
    end

// --- FORMAL VERIFICATION --- //

`ifdef FORMAL

    function [31:0] trunc_33_to_32(input [32:0] val33);
        trunc_33_to_32 = val33[31:0];
    endfunction

    always @(*) begin
        assert(sum == (I_dataS1 + I_dataS2));
        assert(sub[31:0] == (I_dataS1 - I_dataS2));
        assert(eq == (I_dataS1 == I_dataS2));
        assert(lt == ($signed(I_dataS1)) < $signed(I_dataS2));
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
                if($past(I_aluop) == `ALUOP_ADD) assert(O_data == trunc_33_to_32($past(I_dataS1) + $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_SUB) assert(O_data == trunc_33_to_32($past(I_dataS1) - $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_AND) assert(O_data == ($past(I_dataS1) & $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_OR) assert(O_data == ($past(I_dataS1) | $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_XOR) assert(O_data == ($past(I_dataS1) ^ $past(I_dataS2)));
                if($past(I_aluop) == `ALUOP_SLT) begin
                    assert(O_data[0] == $signed($past(I_dataS1)) < $signed($past(I_dataS2)));
                    assert(O_data[31:1] == 31'b0);
                end
                if($past(I_aluop) == `ALUOP_SLTU) begin
                    assert(O_data[0] == $past(I_dataS1) < $past(I_dataS2));
                    assert(O_data[31:1] == 31'b0);
                end

                `ifdef SINGLE_CYCLE_SHIFTER
                    if($past(I_aluop) == `ALUOP_SLL) assert(O_data == ($past(I_dataS1) << $past(I_dataS2[4:0])));
                    if($past(I_aluop) == `ALUOP_SRL) assert(O_data == ($past(I_dataS1) >> $past(I_dataS2[4:0])));
                    if($past(I_aluop) == `ALUOP_SRA) assert(O_data == $unsigned($signed($past(I_dataS1)) >>> $past(I_dataS2[4:0])));
                `endif

            end


            if($past(I_reset)) begin
                assert(O_busy == 1'b0);
            end
        end
    end

`endif


endmodule
