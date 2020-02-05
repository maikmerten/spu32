`ifndef ALUOPS
    `define ALUOPS 1

    `define ALUOP_ADD  4'b0000
    `define ALUOP_SUB  4'b0001
    `define ALUOP_AND  4'b0010
    `define ALUOP_OR   4'b0011
    `define ALUOP_XOR  4'b0100
    `define ALUOP_SLT  4'b0101
    `define ALUOP_SLTU 4'b0110
    `define ALUOP_SLL  4'b0111
    `define ALUOP_SRL  4'b1000
    `define ALUOP_SRA  4'b1001

    `define ALUOP_MUL    4'b1010
    `define ALUOP_MULH   4'b1011
    `define ALUOP_MULHSU 4'b1100
    `define ALUOP_MULHU  4'b1101
    
`endif