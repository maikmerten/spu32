`include "./cpu/riscvdefs.vh"

module decoder(
	input[31:0] I_instr,
	output reg[4:0]	 O_rs1, O_rs2, O_rd,
	output reg[31:0] O_imm,
	output reg[4:0] O_opcode,
	output reg[2:0] O_funct3,
	output reg[6:0] O_funct7
	);

	reg[4:0] opcode;

	always @(*) begin
		opcode = I_instr[6:2];
		O_opcode = opcode;
		O_funct3 = I_instr[14:12];
		O_funct7 = I_instr[31:25];

		O_rs1 = I_instr[19:15];
		O_rs2 = I_instr[24:20];
		O_rd = I_instr[11:7];

		case(opcode)
			`OP_STORE: O_imm = {{20{I_instr[31]}}, I_instr[31:25], I_instr[11:8], I_instr[7]}; // S-type
			`OP_BRANCH: O_imm = {{19{I_instr[31]}}, I_instr[31], I_instr[7], I_instr[30:25], I_instr[11:8], 1'b0}; // SB-type
			`OP_LUI, `OP_AUIPC: O_imm = {I_instr[31:12], {12{1'b0}}};
			`OP_JAL: O_imm = {{19{I_instr[31]}}, I_instr[31], I_instr[19:12], I_instr[20], I_instr[30:25], I_instr[24:21], 1'b0}; // UJ-type
			default: O_imm = {{20{I_instr[31]}}, I_instr[31:20]}; // I-type and R-type. Immediate has no meaning for R-type instructions
		endcase

	end

endmodule
