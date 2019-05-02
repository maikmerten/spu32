`include "./cpu/riscvdefs.vh"

module decoder(
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
	output reg[6:0] O_funct7,
	output reg[5:0] O_branchmask
	);

	reg[31:0] instr;

	reg[4:0] opcode;
	reg[31:0] imm;
	reg[2:0] funct3;
	assign O_funct3 = funct3;
	assign O_opcode = opcode;

	// combinatorial decode of source register information to allow for register read during decode
	assign O_rs1 = I_instr[19:15];
	assign O_rs2 = I_instr[24:20];

	reg isbranch = 0;

	always @(*) begin
		opcode = instr[6:2];
		O_funct7 = instr[31:25];
		O_rd = instr[11:7];
		funct3 = instr[14:12];

		case(opcode)
			`OP_STORE: imm = {{20{I_instr[31]}}, I_instr[31:25], I_instr[11:8], I_instr[7]}; // S-type
			`OP_BRANCH: imm = {{19{I_instr[31]}}, I_instr[31], I_instr[7], I_instr[30:25], I_instr[11:8], 1'b0}; // SB-type
			`OP_LUI, `OP_AUIPC: imm = {I_instr[31:12], {12{1'b0}}};
			`OP_JAL: imm = {{11{I_instr[31]}}, I_instr[31], I_instr[19:12], I_instr[20], I_instr[30:25], I_instr[24:21], 1'b0}; // UJ-type
			default: imm = {{20{I_instr[31]}}, I_instr[31:20]}; // I-type and R-type. Immediate has no meaning for R-type instructions
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

	end

	always @(posedge I_clk) begin
		if(I_en) begin
			instr <= I_instr;
		end
	end

endmodule
