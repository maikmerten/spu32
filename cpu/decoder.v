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
        output reg[4:0] O_opcode,
        output reg O_writeback,
        output reg[2:0] O_funct3,
        output reg[5:0] O_branchmask,
        output reg[3:0] O_aluop,
        output reg[2:0] O_busop,
        output reg O_alumux1,
        output reg O_alumux2,
        output reg[1:0] O_reginputmux
    );

    // Muxer for first operand of ALU
    localparam MUX_ALUDAT1_REGVAL1 = 0;
    localparam MUX_ALUDAT1_PC      = 1;

    // Muxer for second operand of ALU
    localparam MUX_ALUDAT2_REGVAL2 = 0;
    localparam MUX_ALUDAT2_IMM     = 1;

    // Muxer for register data input
    localparam MUX_REGINPUT_ALU = 0;
    localparam MUX_REGINPUT_BUS = 1;
    localparam MUX_REGINPUT_BRU = 2;
    localparam MUX_REGINPUT_MSR = 3;

    wire[31:0] instr = I_instr;

    reg[4:0] opcode;
    reg writeback;
    reg[31:0] imm;
    reg[4:0] rd;
    reg[2:0] funct3;
    reg[6:0] funct7;
    reg[5:0] branchmask;
    reg[3:0] aluop;

    reg[3:0] aluop_op, aluop_opimm;
    reg[2:0] busop, busop_load, busop_store;
    reg alumux1, alumux2;
    reg[1:0] reginputmux;

    // LUI is handled as reg+imm addition, with rs1 being hardwired to zero
    wire is_lui_op = I_instr[6:2] == `OP_LUI;

    // combinatorial decode of source register information to allow for register read during decode
    assign O_rs1 =  is_lui_op ? 5'b00000 : I_instr[19:15];
    assign O_rs2 = I_instr[24:20];

    reg isbranch = 0;

    always @(*) begin
        opcode = instr[6:2];
        funct3 = instr[14:12];
        funct7 = instr[31:25];
        rd = instr[11:7];

        case(opcode)
            `OP_STORE: imm = {{20{instr[31]}}, instr[31:25], instr[11:8], instr[7]}; // S-type
            `OP_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // SB-type
            `OP_LUI, `OP_AUIPC: imm = {instr[31:12], {12{1'b0}}};
            `OP_JAL: imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:25], instr[24:21], 1'b0}; // UJ-type
            default: imm = {{20{instr[31]}}, instr[31:20]}; // I-type and R-type. Immediate has no meaning for R-type instructions
        endcase

        // determine if opcode needs register writeback
        case(opcode)
            `OP_OP, `OP_OPIMM, `OP_LUI, `OP_AUIPC, `OP_LOAD, `OP_JAL, `OP_JALR:  writeback = 1'b1;
            default: writeback = 1'b0;
        endcase

        // determine first ALU data input
        case(opcode)
            `OP_JAL, `OP_AUIPC: alumux1 = MUX_ALUDAT1_PC;
            default:            alumux1 = MUX_ALUDAT1_REGVAL1;
        endcase

        // determine second ALU data input
        case(opcode)
            `OP_OP, `OP_BRANCH: alumux2 = MUX_ALUDAT2_REGVAL2;
            default:            alumux2 = MUX_ALUDAT2_IMM;
        endcase

        // determine register writeback input
        case(opcode)
            `OP_LOAD:           reginputmux = MUX_REGINPUT_BUS;
            `OP_JAL, `OP_JALR:  reginputmux = MUX_REGINPUT_BRU;
            `OP_SYSTEM:         reginputmux = MUX_REGINPUT_MSR;
            default:            reginputmux = MUX_REGINPUT_ALU;
        endcase

        isbranch = (opcode == `OP_BRANCH);
        branchmask = 0;
        case(funct3)
            `FUNC_BEQ:  branchmask[0] = isbranch;
            `FUNC_BNE:  branchmask[1] = isbranch;
            `FUNC_BLT:  branchmask[2] = isbranch;
            `FUNC_BGE:  branchmask[3] = isbranch;
            `FUNC_BLTU: branchmask[4] = isbranch;
            `FUNC_BGEU: branchmask[5] = isbranch;
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

        // select op for alu
        case(opcode)
            `OP_OP   : aluop = aluop_op;
            `OP_OPIMM: aluop = aluop_opimm;
            default  : aluop = `ALUOP_ADD;
        endcase

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

        busop = (opcode == `OP_LOAD ? busop_load : busop_store);

    end

    always @(posedge I_clk) begin
        if(I_en) begin
            // register output signals to gain timing headroom
            O_imm <= imm;
            O_opcode <= opcode;
            O_writeback <= writeback;
            O_funct3 <= funct3;
            O_branchmask <= branchmask;
            O_aluop <= aluop;
            O_rd <= rd;
            O_busop <= busop;
            O_alumux1 <= alumux1;
            O_alumux2 <= alumux2;
            O_reginputmux <= reginputmux;
        end
    end

endmodule
