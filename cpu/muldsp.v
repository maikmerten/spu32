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


    // determine sign/zero-extension for operands
    reg s1_extension, s2_extension;
    always @(*) begin
        s1_extension = 1'b0;
        s2_extension = 1'b0;
        case(I_op)
            `ALUOP_MULH: begin
                s1_extension = I_s1[31]; // sign-extend s1
                s2_extension = I_s2[31]; // sign-extend s2
            end
            `ALUOP_MULHSU: begin
                s1_extension = I_s1[31]; // sign-extend s1
            end
        endcase
    end
 

    wire[63:0] mul_signed = $signed({s1_extension, I_s1}) * $signed({s2_extension, I_s2});
    assign O_result = mul_signed;

endmodule


