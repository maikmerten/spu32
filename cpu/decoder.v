`include "./cpu/riscvdefs.vh"
`include "./cpu/aludefs.vh"
`include "./cpu/busdefs.vh"

module spu32_cpu_decoder(
        input I_clk,
        input I_en,
        /* verilator lint_off UNUSED */
        input[31:0] I_instr,
        /* verilator lint_on UNUSED */
        output[4:0]	O_rs1, O_rs2,
        output reg[4:0] O_rd,
        output reg[31:0] O_imm,
        output[4:0] O_opcode,
        output[2:0] O_funct3,
        output reg[5:0] O_branchmask,
        output reg[3:0] O_aluop,
        output reg[2:0] O_busop
    );

    reg[31:0] instr;

    reg[4:0] opcode;
    reg[31:0] imm;
    reg[2:0] funct3;
    reg[6:0] funct7;

    reg[3:0] aluop_op, aluop_opimm;
    reg[2:0] busop_load, busop_store;

    assign O_funct3 = funct3;
    assign O_opcode = opcode;

    // combinatorial decode of source register information to allow for register read during decode
    assign O_rs1 = I_instr[19:15];
    assign O_rs2 = I_instr[24:20];

    reg isbranch = 0;

    always @(*) begin
        opcode = instr[6:2];
        funct3 = instr[14:12];
        funct7 = instr[31:25];
        O_rd = instr[11:7];

        case(opcode)
            `OP_STORE: imm = {{20{instr[31]}}, instr[31:25], instr[11:8], instr[7]}; // S-type
            `OP_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // SB-type
            `OP_LUI, `OP_AUIPC: imm = {instr[31:12], {12{1'b0}}};
            `OP_JAL: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0}; // UJ-type
            default: imm = {{20{instr[31]}}, instr[31:20]}; // I-type and R-type. Immediate has no meaning for R-type instructions
        endcase

        O_imm = imm;

        isbranch = (opcode == `OP_BRANCH);
        O_branchmask = 0;
        case(funct3)
            `FUNC_BEQ:  O_branchmask[0] = isbranch;
            `FUNC_BNE:  O_branchmask[1] = isbranch;
            `FUNC_BLT:  O_branchmask[2] = isbranch;
            `FUNC_BGE:  O_branchmask[3] = isbranch;
            `FUNC_BLTU: O_branchmask[4] = isbranch;
            `FUNC_BGEU: O_branchmask[5] = isbranch;
        endcase
        
        // OP_OP
        case({funct3, funct7[0]})
            {`FUNC_ADD_SUB, 1'b0}:  aluop_op = funct7[5] ? `ALUOP_SUB : `ALUOP_ADD;
            {`FUNC_SLL, 1'b0}:      aluop_op = `ALUOP_SLL;
            {`FUNC_SLT, 1'b0}:      aluop_op = `ALUOP_SLT;
            {`FUNC_SLTU, 1'b0}:     aluop_op = `ALUOP_SLTU;
            {`FUNC_XOR, 1'b0}:      aluop_op = `ALUOP_XOR;
            {`FUNC_SRL_SRA, 1'b0}:  aluop_op = funct7[5] ? `ALUOP_SRA : `ALUOP_SRL;
            {`FUNC_OR, 1'b0}:       aluop_op = `ALUOP_OR;
            {`FUNC_AND, 1'b0}:      aluop_op = `ALUOP_AND;
            {`FUNC_MUL, 1'b1}:      aluop_op = `ALUOP_MUL;
            {`FUNC_MULH, 1'b1}:     aluop_op = `ALUOP_MULH;
            {`FUNC_MULHSU, 1'b1}:   aluop_op = `ALUOP_MULHSU;
            {`FUNC_MULHU, 1'b1}:    aluop_op = `ALUOP_MULHU;
            default:        aluop_op = `ALUOP_ADD;
        endcase

        // OP_OPIMM
        case(funct3)
            `FUNC_ADDI:         aluop_opimm = `ALUOP_ADD;
            `FUNC_SLLI:         aluop_opimm = `ALUOP_SLL;
            `FUNC_SLTI:         aluop_opimm = `ALUOP_SLT;
            `FUNC_SLTIU:        aluop_opimm = `ALUOP_SLTU;
            `FUNC_XORI:         aluop_opimm = `ALUOP_XOR;
            `FUNC_SRLI_SRAI:    aluop_opimm = funct7[5] ? `ALUOP_SRA : `ALUOP_SRL;
            `FUNC_ORI:          aluop_opimm = `ALUOP_OR;
            `FUNC_ANDI:         aluop_opimm = `ALUOP_AND;
            default:            aluop_opimm = `ALUOP_ADD;
        endcase

        O_aluop = (opcode == `OP_OPIMM ? aluop_opimm : aluop_op);

        // OP_LOAD
        case(funct3)
            `FUNC_LB:   busop_load = `BUSOP_READB;
            `FUNC_LH:   busop_load = `BUSOP_READH;
            `FUNC_LW:   busop_load = `BUSOP_READW;
            `FUNC_LBU:  busop_load = `BUSOP_READBU;
            default:    busop_load = `BUSOP_READHU; // FUNC_LHU
        endcase

        // OP_STORE
        case(funct3)
            `FUNC_SB:   busop_store = `BUSOP_WRITEB;
            `FUNC_SH:   busop_store = `BUSOP_WRITEH;
            default:    busop_store = `BUSOP_WRITEW; // FUNC_SW
        endcase

        O_busop = (opcode == `OP_LOAD ? busop_load : busop_store);

    end

    always @(posedge I_clk) begin
        if(I_en) begin
            instr <= I_instr;
        end
    end

endmodule
