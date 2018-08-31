package de.maikmerten.spu32.emu.cpu;

import de.maikmerten.spu32.emu.bus.Bus;

/**
 *
 * @author maik
 */
public class CPU {

	private final Bus bus;
	private final int[] registers = new int[32];

	private final int resetvector, trapvector;

	// program counter
	private int pc;

	// current instruction
	private int instructionword;

	// decoded information
	private int opcode;
	private int func3, func7;
	private int rs1, rs2, rd;
	private int immediate;

	// Exception causes
	private enum Cause {
		NONE(0x0),
		EXTERNAL_INTERRUPT(0x8000000b),
		INVALID_INSTRUCTION(0x0000002),
		BREAK(0x00000003),
		ECALL(0x0000000b);

		private final int value;

		private Cause(int value) {
			this.value = value;
		}
	}

	private int mcause;
	private int epc = 0; // Exception pc
	private int evect = 0;
	private boolean meie = false;
	private boolean meie_prev = false;
	private boolean interrupt_pending = false;

	// opcodes
	private final static int OP_OP = 0b01100; // R-type
	private final static int OP_JALR = 0b11001; // I-type
	private final static int OP_LOAD = 0b00000; // I-type
	private final static int OP_OPIMM = 0b00100; // I-type
	private final static int OP_SYSTEM = 0b11100; // I-type
	private final static int OP_MISCMEM = 0b00011; // I-type?
	private final static int OP_STORE = 0b01000; // S-type
	private final static int OP_BRANCH = 0b11000; // SB-type
	private final static int OP_LUI = 0b01101; // U-type
	private final static int OP_AUIPC = 0b00101; // U-type
	private final static int OP_JAL = 0b11011; // UJ-type

	// functions
	private final static int FUNC_BEQ = 0b000;
	private final static int FUNC_BNE = 0b001;
	private final static int FUNC_BLT = 0b100;
	private final static int FUNC_BGE = 0b101;
	private final static int FUNC_BLTU = 0b110;
	private final static int FUNC_BGEU = 0b111;

	private final static int FUNC_LB = 0b000;
	private final static int FUNC_LH = 0b001;
	private final static int FUNC_LW = 0b010;
	private final static int FUNC_LBU = 0b100;
	private final static int FUNC_LHU = 0b101;

	private final static int FUNC_SB = 0b000;
	private final static int FUNC_SH = 0b001;
	private final static int FUNC_SW = 0b010;

	private final static int FUNC_ADDI = 0b000;
	private final static int FUNC_SLLI = 0b001;
	private final static int FUNC_SLTI = 0b010;
	private final static int FUNC_SLTIU = 0b011;
	private final static int FUNC_XORI = 0b100;
	private final static int FUNC_SRLI_SRAI = 0b101;
	private final static int FUNC_ORI = 0b110;
	private final static int FUNC_ANDI = 0b111;

	private final static int FUNC_ADD_SUB = 0b000;
	private final static int FUNC_SLL = 0b001;
	private final static int FUNC_SLT = 0b010;
	private final static int FUNC_SLTU = 0b011;
	private final static int FUNC_XOR = 0b100;
	private final static int FUNC_SRL_SRA = 0b101;
	private final static int FUNC_OR = 0b110;
	private final static int FUNC_AND = 0b111;

	private final static int FUNC_FENCE = 0b000;
	private final static int FUNC_FENCEI = 0b001;

	private final static int FUNC_ECALL_EBREAK = 0b000;
	private final static int FUNC_CSRRW = 0b001;

	private final static int SYSTEM_ECALL = 0x000;
	private final static int SYSTEM_EBREAK = 0x001;
	private final static int SYSTEM_MRET = 0x302;

	// the lowermost two bits of the immediate are used to select the MSR
	private final int MSR_MSTATUS = 0x0;
	private final int MSR_CAUSE = 0x1;
	private final int MSR_EPC = 0x2;
	private final int MSR_EVECT = 0x3;

	public CPU(Bus bus, int resetvector, int trapvector) {
		super();
		this.bus = bus;
		this.resetvector = resetvector;
		this.trapvector = trapvector;

		this.reset();
	}

	public final void reset() {
		this.pc = this.resetvector;
		this.evect = this.trapvector;
		this.meie = false;
	}

	public void nextStep() {
		this.interrupt_pending = bus.interruptRaised();
		if(this.interrupt_pending && this.meie) {
			enterException(Cause.EXTERNAL_INTERRUPT);
			return;
		}
		
		this.instructionword = bus_lw(this.pc);
		int nextpc = this.pc + 4;

		//System.out.println("PC: " + this.pc);
		decode();

		int imm = this.immediate;
		// fetch registers
		int rval1 = getRegister(this.rs1);
		int rval2 = getRegister(this.rs2);
		int result = getRegister(this.rd);

		// execute
		switch (this.opcode) {
			case OP_OP:
				switch (this.func3) {
					case FUNC_ADD_SUB:
						if ((this.func7 & 0b0100000) == 0) {
							// ADD
							result = rval1 + rval2;
						} else {
							// SUB
							result = rval1 - rval2;
						}
						break;
					case FUNC_SLL:
						result = rval1 << (rval2 & 0b11111);
						break;
					case FUNC_SLT:
						result = (rval1 < rval2) ? 1 : 0;
						break;
					case FUNC_SLTU:
						result = (Integer.compareUnsigned(rval1, rval2) == -1) ? 1 : 0;
						break;
					case FUNC_XOR:
						result = rval1 ^ rval2;
						break;
					case FUNC_SRL_SRA:
						if ((this.func7 & 0b0100000) == 0) {
							// SRL
							result = rval1 >>> (rval2 & 0b11111);
						} else {
							// SRA
							result = rval1 >> (rval2 & 0b11111);
						}
						break;
					case FUNC_OR:
						result = rval1 | rval2;
						break;
					case FUNC_AND:
						result = rval1 & rval2;
						break;
				}
				break;

			case OP_OPIMM:
				switch (this.func3) {
					case FUNC_ADDI:
						result = rval1 + imm;
						break;
					case FUNC_SLLI:
						result = rval1 << (imm & 0b11111);
						break;
					case FUNC_SLTI:
						result = (rval1 < imm) ? 1 : 0;
						break;
					case FUNC_SLTIU:
						result = (Integer.compareUnsigned(rval1, imm) == -1) ? 1 : 0;
						break;
					case FUNC_XORI:
						result = rval1 ^ imm;
						break;
					case FUNC_SRLI_SRAI:
						if ((this.func7 & 0b0100000) == 0) {
							// SRLI
							result = rval1 >>> (imm & 0b11111);
						} else {
							// SRAI
							result = rval1 >> (imm & 0b11111);
						}
						break;
					case FUNC_ORI:
						result = rval1 | imm;
						break;
					case FUNC_ANDI:
						result = rval1 & imm;
						break;
				}
				break;

			case OP_LOAD:
				switch (this.func3) {
					case FUNC_LB:
						result = bus_lb(rval1 + imm);
						break;
					case FUNC_LH:
						result = bus_lh(rval1 + imm);
						break;
					case FUNC_LW:
						result = bus_lw(rval1 + imm);
						break;
					case FUNC_LBU:
						result = bus_lbu(rval1 + imm);
						break;
					case FUNC_LHU:
						result = bus_lhu(rval1 + imm);
						break;
				}
				break;

			case OP_STORE:
				switch (this.func3) {
					case FUNC_SB:
						bus_sb(rval1 + imm, rval2);
						break;
					case FUNC_SH:
						bus_sh(rval1 + imm, rval2);
						break;
					case FUNC_SW:
						bus_sw(rval1 + imm, rval2);
						break;
				}
				break;

			case OP_JAL:
				result = nextpc;
				nextpc = this.pc + imm;
				break;

			case OP_JALR:
				result = nextpc;
				nextpc = (rval1 + imm) & 0xFFFFFFFE;
				break;

			case OP_BRANCH:
				switch (this.func3) {
					case FUNC_BEQ:
						if (rval1 == rval2) {
							nextpc = this.pc + imm;
						}
						break;
					case FUNC_BNE:
						if (rval1 != rval2) {
							nextpc = this.pc + imm;
						}
						break;
					case FUNC_BLT:
						if (rval1 < rval2) {
							nextpc = this.pc + imm;
						}
						break;
					case FUNC_BGE:
						if (rval1 >= rval2) {
							nextpc = this.pc + imm;
						}
						break;
					case FUNC_BLTU:
						if (Integer.compareUnsigned(rval1, rval2) == -1) {
							nextpc = this.pc + imm;
						}
						break;
					case FUNC_BGEU:
						if (Integer.compareUnsigned(rval1, rval2) >= 0) {
							nextpc = this.pc + imm;
						}
						break;
				}
				break;

			case OP_LUI:
				result = imm;
				break;

			case OP_AUIPC:
				result = this.pc + imm;
				break;

			case OP_MISCMEM:
				break;

			case OP_SYSTEM:
				switch (this.func3) {
					case FUNC_ECALL_EBREAK: {
						switch (this.immediate & 0xFFF) {
							case SYSTEM_EBREAK: {
								enterException(Cause.BREAK);
								return;
							}

							case SYSTEM_ECALL: {
								enterException(Cause.ECALL);
								return;
							}

							case SYSTEM_MRET: {
								returnFromException();
								return;
							}
						}
					}

					case FUNC_CSRRW:
						result = readCSR();
						// bit 11 of immediate denotes if non-standard machine-mode MSR is writable or not
						if((this.immediate & 0x800) == 0) {
							writeCSR(rval1);
						}
						break;

					default:
						enterException(Cause.INVALID_INSTRUCTION);
						return;
				}
				break;

			default: 
				enterException(Cause.INVALID_INSTRUCTION);
				return;

		}

		// register writeback
		setRegister(this.rd, result);
		// commit new PC
		this.pc = nextpc;
	}

	private void decode() {
		this.opcode = (this.instructionword >> 2) & 0b11111;
		this.rd = (this.instructionword >> 7) & 0b11111;
		this.func3 = (this.instructionword >> 12) & 0b111;
		this.rs1 = (this.instructionword >> 15) & 0b11111;
		this.rs2 = (this.instructionword >> 20) & 0b11111;
		this.func7 = (this.instructionword >>> 25);

		int imm, tmp;

		switch (this.opcode) {
			case OP_STORE: // S-type
				//System.out.println("S-type");
				imm = this.rd | (this.func7 << 5);
				imm <<= 20; // sign...
				imm >>= 20; // ... extend
				break;

			case OP_BRANCH: // SB-type
				//System.out.println("SB-type");
				imm = (this.rd & 0b00001) << 11;
				imm |= (this.rd & 0b11110);
				imm |= (this.func7 & 0b0111111) << 5;
				imm |= (this.func7 & 0b1000000) << 6;
				imm <<= 19; // sign...
				imm >>= 19; // ... extend
				break;

			case OP_LUI:   // U-type
			case OP_AUIPC: // U-type
				//System.out.println("U-type");
				imm = (this.instructionword & 0xFFFFF000);
				break;

			case OP_JAL: // UJ-type
				//System.out.println("UJ-type");
				tmp = this.instructionword >>> 12;
				imm = (tmp & 0xFF) << 12;
				imm |= ((tmp >> 8) & 0x1) << 11;
				imm |= ((tmp >> 9) & 0x3FF) << 1;
				imm |= ((tmp >> 19) & 0x1) << 20;
				imm <<= 12; // sign...
				imm >>= 12; // ... extend
				break;

			default: // I-type and R-type (latter without actual immediate)
				//System.out.println("I-type or R-type");
				imm = this.instructionword >> 20;

		}

		this.immediate = imm;
	}

	private void setRegister(int regnum, int value) {
		registers[regnum] = value;
		registers[0] = 0;
	}

	private int getRegister(int regnum) {
		return registers[regnum];
	}

	private void enterException(Cause cause) {
		this.mcause = cause.value;
		this.epc = this.pc;
		this.meie_prev = this.meie;
		this.meie = false;
		this.pc = this.evect;
	}

	private void returnFromException() {
		this.pc = this.epc;
		this.meie = this.meie_prev;
		this.mcause = Cause.NONE.value;
	}

	private int readCSR() {
		// use the lowermost two bits to address CSR
		int csr = this.immediate & 0x3;
		int result = 0;

		switch (csr) {
			case MSR_MSTATUS:
				result |= this.meie ? 0x1 : 0x0;
				result |= this.meie_prev ? 0x2 : 0x0;
				result |= this.interrupt_pending ? 0x4 : 0x0;
				break;

			case MSR_CAUSE:
				result = this.mcause;
				break;

			case MSR_EPC:
				result = this.epc;
				break;
			
			case MSR_EVECT:
				result = this.evect;
				break;
		}

		return result;
	}

	private void writeCSR(int value) {
		// use the lowermost two bits to address CSR
		int csr = this.immediate & 0x3;

		switch (csr) {
			case MSR_MSTATUS:
				this.meie = (value & 0x1) != 0;
				this.meie_prev = (value & 0x2) != 0;
				break;

			case MSR_CAUSE:
				this.mcause = value;
				break;

			case MSR_EPC:
				this.epc = value;
				break;
			
			case MSR_EVECT:
				this.evect = value;
				break;
		}

	}

	private int bus_lb(int address) {
		return (int) bus.readByte(address);
	}

	private int bus_lbu(int address) {
		return ((int) bus.readByte(address)) & 0xFF;
	}

	private int bus_lh(int address) {
		byte b1 = bus.readByte(address);
		byte b2 = bus.readByte(address + 1);
		int result = (int) b2;
		result <<= 8;
		result |= ((int) b1) & 0xFF;
		return result;
	}

	private int bus_lhu(int address) {
		byte b1 = bus.readByte(address);
		byte b2 = bus.readByte(address + 1);
		int result = (int) b2;
		result <<= 8;
		result |= (b1 & 0xFF);
		result &= 0xFFFF;
		return result;
	}

	private int bus_lw(int address) {
		byte b1 = bus.readByte(address);
		byte b2 = bus.readByte(address + 1);
		byte b3 = bus.readByte(address + 2);
		byte b4 = bus.readByte(address + 3);

		int result = b4;
		result <<= 8;
		result |= (b3 & 0xFF);
		result <<= 8;
		result |= (b2 & 0xFF);
		result <<= 8;
		result |= (b1 & 0xFF);
		return result;
	}

	private void bus_sb(int address, int value) {
		bus.writeByte(address, (byte) (value & 0xFF));
	}

	private void bus_sh(int address, int value) {
		bus.writeByte(address, (byte) ((value) & 0xFF));
		bus.writeByte(address + 1, (byte) ((value >> 8) & 0xFF));
	}

	private void bus_sw(int address, int value) {
		bus.writeByte(address, (byte) ((value) & 0xFF));
		bus.writeByte(address + 1, (byte) ((value >> 8) & 0xFF));
		bus.writeByte(address + 2, (byte) ((value >> 16) & 0xFF));
		bus.writeByte(address + 3, (byte) ((value >> 24) & 0xFF));
	}

	// expose decoding of immediate values for unit testing
	public int testImmediateDecode(int instructionWord) {
		this.instructionword = instructionWord;
		this.decode();
		return this.immediate;
	}

}
