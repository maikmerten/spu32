`ifndef RISCVDEFS
    `define RISCVDEFS 1

    // Opcodes
    `define OP_OP 		5'b01100	// R-type
    `define OP_CUSTOM0	5'b00010	// R-type

    `define OP_JALR		5'b11001	// I-type
    `define OP_LOAD		5'b00000	// I-type
    `define OP_OPIMM 	5'b00100	// I-type
    `define OP_SYSTEM	5'b11100	// I-type
    `define OP_MISCMEM	5'b00011	// I-type?

    `define OP_STORE 	5'b01000	// S-type

    `define OP_BRANCH 	5'b11000	// SB-type

    `define OP_LUI		5'b01101	// U-type
    `define OP_AUIPC 	5'b00101	// U-type

    `define OP_JAL		5'b11011	// UJ-type

    // Functions
    `define FUNC_BEQ	3'b000
    `define FUNC_BNE	3'b001
    `define FUNC_BLT	3'b100
    `define FUNC_BGE	3'b101
    `define FUNC_BLTU	3'b110
    `define FUNC_BGEU	3'b111

    `define FUNC_LB		3'b000
    `define FUNC_LH		3'b001
    `define FUNC_LW		3'b010
    `define FUNC_LBU	3'b100
    `define FUNC_LHU	3'b101

    `define FUNC_SB		3'b000
    `define FUNC_SH		3'b001
    `define FUNC_SW		3'b010

    `define FUNC_ADDI	3'b000
    `define FUNC_SLLI	3'b001
    `define FUNC_SLTI	3'b010
    `define FUNC_SLTIU	3'b011
    `define FUNC_XORI	3'b100
    `define FUNC_SRLI_SRAI	3'b101
    `define FUNC_ORI	3'b110
    `define FUNC_ANDI	3'b111

    `define FUNC_ADD_SUB	3'b000
    `define FUNC_SLL	3'b001
    `define FUNC_SLT	3'b010
    `define FUNC_SLTU	3'b011
    `define FUNC_XOR	3'b100
    `define FUNC_SRL_SRA	3'b101
    `define FUNC_OR		3'b110
    `define FUNC_AND	3'b111

    `define FUNC_FENCE	3'b000
    `define FUNC_FENCEI	3'b001

    `define FUNC_ECALL_EBREAK	3'b000
    `define FUNC_CSRRW			3'b001

    `define FUNC_MUL    3'b000
    `define FUNC_MULH   3'b001
    `define FUNC_MULHSU 3'b010
    `define FUNC_MULHU  3'b011

    // imm[11:0] of SYSTEM-opcode encodes function
    `define SYSTEM_ECALL	12'b000000000000
    `define SYSTEM_EBREAK	12'b000000000001
    `define SYSTEM_MRET		12'b001100000010


    // Registers
    `define R0 		5'b00000
    `define R1		5'b00001
    `define R2		5'b00010
    `define R3		5'b00011
    `define R4		5'b00100
    `define R5		5'b00101
    `define T0		5'b00101
    `define R6		5'b00110
    `define T1		5'b00110
    `define R7		5'b00111
    `define T2		5'b00111
    `define R8		5'b01000
    `define R9		5'b01001
    `define R10		5'b01010
    `define R11		5'b01011
    `define R12		5'b01100
    `define R13		5'b01101
    `define R14		5'b01110
    `define R15		5'b01111
    `define R16		5'b10000
    `define R17		5'b10001
    `define R18		5'b10010
    `define R19		5'b10011
    `define R20		5'b10100
    `define R21		5'b10101
    `define R22		5'b10110
    `define R23		5'b10111
    `define R24		5'b11000
    `define R25		5'b11001
    `define R26		5'b11010
    `define R27		5'b11011
    `define R28		5'b11100
    `define R29		5'b11101
    `define R30		5'b11110
    `define R31		5'b11111

`endif
