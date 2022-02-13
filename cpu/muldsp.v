`default_nettype none

`include "cpu/aludefs.vh"

module spu32_cpu_muldsp(
        input I_clk,
        input I_en,
        input I_reset,
        input[3:0] I_op,
        input[31:0] I_s1,
        input[31:0] I_s2,
        output[63:0] O_result,
        output O_busy
    );

    // single-cycle multiplication with inferred DSP blocks
    assign O_busy = 0;


    // determine signedness according to MUL-operation
    reg s1_signed, s2_signed;
    always @(*) begin
        case(I_op)
            `ALUOP_MULH: begin
                s1_signed = 1'b1;
                s2_signed = 1'b1;
            end
            `ALUOP_MULHSU: begin
                s1_signed = 1'b1;
                s2_signed = 1'b0;
            end
            default: begin
                s1_signed = 1'b0;
                s2_signed = 1'b0;
            end
        endcase
    end

/*
    // Alternative approach with only one unsigned multiplier. This keeps track
    // of the sign-bits and uses two-complement operations to ensure correct
    // signedness. However, this adds plenty of logic for negating bits and
    // and doing the +1 to convert two-complement representations.
    assign O_busy = 0;
    wire[63:0] result;

    wire s1_negative = I_s1[31] & s1_signed;
    wire s2_negative = I_s2[31] & s2_signed;
    wire result_negative = s1_negative ^ s2_negative;

    wire[31:0] s1 = s1_negative ? ~I_s1 + 1 : I_s1;
    wire[31:0] s2 = s2_negative ? ~I_s2 + 1 : I_s2;

    wire[63:0] mult = s1 * s2;

    always @(*) begin
        result = result_negative ? ~mult + 1 : mult;
    end
    assign O_result = result;*/
    
    // This approach does three multiplications in parallel (DSP-heavy!)
    // and chooses the upmost 32-bit according to operation.

    wire[63:0] mul_signed = $signed(I_s1) * $signed(I_s2);
    wire[63:0] mul_unsigned = $unsigned(I_s1) * $unsigned(I_s2);
    // In Verilog, mixed signed/unsigned multiplications are *unsigned*!
    // Thus do signed multiplication with zero-extension for the unsigned
    // operand.
    wire[63:0] mul_signed_unsigned = $signed(I_s1) * $signed({1'b0,I_s2});

    reg[31:0] mulhi;
    always @(*) begin
        case({s1_signed, s2_signed})
            2'b00: mulhi[31:0] = mul_unsigned[63:32];
            2'b11: mulhi[31:0] = mul_signed[63:32];
            default: mulhi[31:0] = mul_signed_unsigned[63:32];
        endcase
    end
    wire[63:0] result = {mulhi, mul_signed[31:0]};
    assign O_result = result;

endmodule


