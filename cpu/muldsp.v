`default_nettype none

`include "cpu/aludefs.vh"

module spu32_cpu_muldsp(
        input I_clk,
        input I_en,
        input I_reset,
        input[3:0] I_op,
        input[1:0] I_op_signed,
        input[31:0] I_s1,
        input[31:0] I_s2,
        output[63:0] O_result,
        output O_busy
    );

    // single-cycle multiplication with inferred DSP blocks
    assign O_busy = 0;

    wire s1_extension = I_op_signed[0] & I_s1[31];
    wire s2_extension = I_op_signed[1] & I_s2[31];
 

    wire[63:0] mul_signed = $signed({s1_extension, I_s1}) * $signed({s2_extension, I_s2});
    assign O_result = mul_signed;

endmodule


