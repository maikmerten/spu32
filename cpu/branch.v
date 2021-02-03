`default_nettype none

module spu32_cpu_branch(
        input I_clk,
        input I_en,
        input I_evaluate_branch,
        input[5:0] I_branchmask,
        input I_lt,
        input I_ltu,
        input I_eq,
        input[31:0] I_pc,
        input[31:0] I_imm,
        output[31:0] O_nextpc,
        output O_misaligned
    );


    reg[31:0] nextpc;

    wire branch = (I_branchmask & {!I_ltu, I_ltu, !I_lt, I_lt, !I_eq, I_eq}) != 0;
    wire[31:0] dest = (I_evaluate_branch & branch) ? I_imm : 32'h00000004;


    assign O_nextpc = nextpc;
    assign O_misaligned = nextpc[1:0] != 2'b00;


    always @(posedge I_clk) begin
        if(I_en) begin
            nextpc <= I_pc + dest;
        end
    end


endmodule
