`include "./cpu/alu.v"
`include "./cpu/bus_wb8.v"
`include "./cpu/decoder.v"
`include "./cpu/registers.v"


module cpu
    #(
        parameter VECTOR_RESET = 32'd0,
        parameter VECTOR_EXCEPTION = 32'd16
    )
    (
        input CLK_I,
	    input ACK_I,
	    input[7:0] DAT_I,
	    input RST_I,
        input INTERRUPT_I,
	    output[31:0] ADR_O,
	    output[7:0] DAT_O,
	    output CYC_O,
	    output STB_O,
	    output WE_O
    );

    wire clk, reset;
    assign clk = CLK_I;
    assign reset = RST_I;

    // MSRS
    reg[31:0] instr, pc, epc;
    reg[31:0] evect = VECTOR_EXCEPTION;
     // current and previous machine-mode external interrupt enable
    reg meie = 0, meie_prev = 0;
     // machine cause register, mcause[4] denotes interrupt, mcause[3:0] encodes exception code
    reg[4:0] mcause = 0;

    localparam CAUSE_EXTERNAL_INTERRUPT     = 5'b11011;
    localparam CAUSE_INVALID_INSTRUCTION    = 5'b00010;
    localparam CAUSE_BREAK                  = 5'b00011;
    localparam CAUSE_ECALL                  = 5'b01011;

    // ALU instance
    reg alu_en = 0;
    reg[3:0] alu_op = 0;
    wire[31:0] alu_dataout;
    reg[31:0] alu_dataS1, alu_dataS2;
    wire alu_busy, alu_lt, alu_ltu, alu_eq;

    alu alu_inst(
        .I_clk(clk),
        .I_en(alu_en),
        .I_reset(reset),
        .I_dataS1(alu_dataS1),
        .I_dataS2(alu_dataS2),
        .I_aluop(alu_op),
        .O_busy(alu_busy),
        .O_data(alu_dataout),
        .O_lt(alu_lt),
        .O_ltu(alu_ltu),
        .O_eq(alu_eq)
    );
    
    reg bus_en = 0;
    reg[2:0] bus_op = 0;
    wire[31:0] bus_dataout;
    reg[31:0] bus_addr;
    wire bus_busy;

    reg reg_we = 0, reg_re = 0;
    wire[31:0] reg_val1, reg_val2;
    reg[31:0] reg_datain;

    // Bus instance
    bus_wb8 bus_inst(
        .I_en(bus_en),
        .I_op(bus_op),
        .I_data(reg_val2),
        .I_addr(bus_addr),
        .O_data(bus_dataout),
        .O_busy(bus_busy),

        .CLK_I(clk),
	    .ACK_I(ACK_I),
	    .DAT_I(DAT_I),
	    .RST_I(RST_I),
	    .ADR_O(ADR_O),
	    .DAT_O(DAT_O),
	    .CYC_O(CYC_O),
	    .STB_O(STB_O),
	    .WE_O(WE_O)
    );

    // Decoder instance
    wire[4:0] dec_rs1, dec_rs2, dec_rd;
    wire[31:0] dec_imm;
    wire[4:0] dec_opcode;
    wire[2:0] dec_funct3;
    wire[6:0] dec_funct7;

    decoder dec_inst(
        .I_instr(instr),
        .O_rs1(dec_rs1),
        .O_rs2(dec_rs2),
        .O_rd(dec_rd),
        .O_imm(dec_imm),
        .O_opcode(dec_opcode),
        .O_funct3(dec_funct3),
        .O_funct7(dec_funct7)
	);

    // Registers instance


    registers reg_inst(
        .I_clk(clk),
        .I_data(reg_datain),
        .I_rs1(dec_rs1),
        .I_rs2(dec_rs2),
        .I_rd(dec_rd),
        .I_re(reg_re),
        .I_we(reg_we),
        .O_regval1(reg_val1),
        .O_regval2(reg_val2)
    );

    // Muxer for first operand of ALU
    localparam MUX_ALUDAT1_REGVAL1 = 0;
    localparam MUX_ALUDAT1_PC      = 1;
    reg mux_alu_s1_sel = MUX_ALUDAT1_REGVAL1;
    always @(*) begin
        case(mux_alu_s1_sel)
            MUX_ALUDAT1_REGVAL1: alu_dataS1 = reg_val1;
            default:             alu_dataS1 = pc; // MUX_ALUDAT1_PC
        endcase
    end

    // Muxer for second operand of ALU
    localparam MUX_ALUDAT2_REGVAL2 = 0;
    localparam MUX_ALUDAT2_IMM     = 1;
    localparam MUX_ALUDAT2_INSTLEN = 2;
    reg[1:0] mux_alu_s2_sel = MUX_ALUDAT2_REGVAL2;
    always @(*) begin
        case(mux_alu_s2_sel)
            MUX_ALUDAT2_REGVAL2: alu_dataS2 = reg_val2;
            MUX_ALUDAT2_IMM:     alu_dataS2 = dec_imm;
            default:             alu_dataS2 = 4; // MUX_ALUDAT2_INSTLEN
        endcase
    end

    // Muxer for bus address
    localparam MUX_BUSADDR_ALU = 0;
    localparam MUX_BUSADDR_PC  = 1;
    reg mux_bus_addr_sel = MUX_BUSADDR_ALU;
    always @(*) begin
        case(mux_bus_addr_sel)
            MUX_BUSADDR_ALU: bus_addr = alu_dataout;
            default:         bus_addr = pc; // MUX_BUSADDR_PC
        endcase
    end

    // Muxer for MSRs
    wire[1:0] mux_msr_sel;
    reg[31:0] msr_data;
    assign mux_msr_sel = dec_imm[1:0];
    wire[31:0] mcause32;
    assign mcause32 = {mcause[4], {27{1'b0}}, mcause[3:0]};
    wire[31:0] mstatus32;
    assign mstatus32 = {{29{1'b0}}, INTERRUPT_I, meie_prev, meie};

    localparam MSR_MSTATUS = 2'b00;
    localparam MSR_CAUSE   = 2'b01;
    localparam MSR_EPC     = 2'b10;
    localparam MSR_EVECT   = 2'b11;

    always @(*) begin
        case(mux_msr_sel)
            MSR_MSTATUS: msr_data = mstatus32;
            MSR_CAUSE:   msr_data = mcause32;
            MSR_EPC:     msr_data = epc;
            default:     msr_data = evect;
        endcase
    end


    // Muxer for register data input
    localparam MUX_REGINPUT_ALU = 0;
    localparam MUX_REGINPUT_BUS = 1;
    localparam MUX_REGINPUT_IMM = 2;
    localparam MUX_REGINPUT_MSR = 3;
    reg[1:0] mux_reg_input_sel = MUX_REGINPUT_ALU;
    always @(*) begin
        case(mux_reg_input_sel)
            MUX_REGINPUT_ALU: reg_datain = alu_dataout;
            MUX_REGINPUT_BUS: reg_datain = bus_dataout;
            MUX_REGINPUT_IMM: reg_datain = dec_imm;
            default:          reg_datain = msr_data; // MUX_REGINPUT_MSR
        endcase
    end

    localparam STATE_RESET          = 0;
    localparam STATE_FETCH          = 1;
    localparam STATE_DECODE         = 2;
    localparam STATE_REGREAD        = 3;
    localparam STATE_JAL_JALR1      = 4;
    localparam STATE_JAL_JALR2      = 5;
    localparam STATE_LUI            = 6;
    localparam STATE_AUIPC          = 7;
    localparam STATE_OP             = 8;
    localparam STATE_OPIMM          = 9;
    localparam STATE_STORE1         = 10;
    localparam STATE_STORE2         = 11;
    localparam STATE_LOAD1          = 12;
    localparam STATE_LOAD2          = 13;
    localparam STATE_BRANCH1        = 14;
    localparam STATE_BRANCH2        = 15;
    localparam STATE_TRAP1          = 16;
    localparam STATE_REGWRITEBUS    = 17;
    localparam STATE_REGWRITEALU    = 18;
    localparam STATE_PCNEXT         = 19;
    localparam STATE_PCREGIMM       = 20;
    localparam STATE_PCIMM          = 21;
    localparam STATE_PCUPDATE_FETCH = 22;
    localparam STATE_SYSTEM         = 23;
    localparam STATE_CSRRW1         = 24;
    localparam STATE_CSRRW2         = 25;


    reg[4:0] state, prevstate = STATE_RESET, nextstate = STATE_RESET;

    wire busy;
    assign busy = alu_busy | bus_busy;

    // only transition to new state if not busy
    always @(*) begin
        state = busy ? prevstate : nextstate;
    end

    always @(negedge clk) begin

        alu_en <= 0;
        bus_en <= 0;
        reg_re <= 0;
        reg_we <= 0;

        mux_alu_s1_sel <= 0;
        mux_alu_s2_sel <= 0;
        mux_reg_input_sel <= 0;

        alu_op <= `ALUOP_ADD;

        // remember currently active state to return to if busy
        prevstate <= state;

        case(state)
            STATE_RESET: begin
                pc <= VECTOR_RESET;
                meie <= 0; // disable machine-mode external interrupt
                nextstate <= STATE_FETCH;
                evect <= VECTOR_EXCEPTION;
            end

            STATE_FETCH: begin
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= MUX_BUSADDR_PC;
                nextstate <= STATE_DECODE;
            end

            STATE_DECODE: begin
                instr <= bus_dataout;
                nextstate <= STATE_REGREAD;

                // checking for interrupt here because no bus operations are active here
                // TODO: find a proper place that doesn't let an instruction fetch go to waste
                if(meie & INTERRUPT_I) begin
                    mcause <= CAUSE_EXTERNAL_INTERRUPT;
                    nextstate <= STATE_TRAP1;
                end

            end

            STATE_REGREAD: begin
                reg_re <= 1;
                case(dec_opcode)
                    `OP_OP:         nextstate <= STATE_OP;
                    `OP_OPIMM:      nextstate <= STATE_OPIMM;
                    `OP_LOAD:       nextstate <= STATE_LOAD1;
                    `OP_STORE:      nextstate <= STATE_STORE1;
                    `OP_JAL:        nextstate <= STATE_JAL_JALR1;
                    `OP_JALR:       nextstate <= STATE_JAL_JALR1;
                    `OP_BRANCH:     nextstate <= STATE_BRANCH1;
                    `OP_LUI:        nextstate <= STATE_LUI;
                    `OP_AUIPC:      nextstate <= STATE_AUIPC;
                    `OP_MISCMEM:    nextstate <= STATE_PCNEXT; // nop
                    `OP_SYSTEM:     nextstate <= STATE_SYSTEM;
                    default:        nextstate <= STATE_TRAP1;
                endcase
            end

            STATE_OP: begin
                alu_en <= 1;
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_REGVAL2;
                case(dec_funct3)
                    `FUNC_ADD_SUB:  alu_op <= dec_funct7[5] ? `ALUOP_SUB : `ALUOP_ADD;
                    `FUNC_SLL:      alu_op <= `ALUOP_SLL;
                    `FUNC_SLT:      alu_op <= `ALUOP_SLT;
                    `FUNC_SLTU:     alu_op <= `ALUOP_SLTU;
                    `FUNC_XOR:      alu_op <= `ALUOP_XOR;
                    `FUNC_SRL_SRA:  alu_op <= dec_funct7[5] ? `ALUOP_SRA : `ALUOP_SRL;
                    `FUNC_OR:       alu_op <= `ALUOP_OR;
                    `FUNC_AND:      alu_op <= `ALUOP_AND;
                    default:        alu_op <= `ALUOP_ADD;
                endcase
                nextstate <= STATE_REGWRITEALU;
            end

            STATE_OPIMM: begin
                alu_en <= 1;
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                case(dec_funct3)
                    `FUNC_ADDI:         alu_op <= `ALUOP_ADD;
                    `FUNC_SLLI:         alu_op <= `ALUOP_SLL;
                    `FUNC_SLTI:         alu_op <= `ALUOP_SLT;
                    `FUNC_SLTIU:        alu_op <= `ALUOP_SLTU;
                    `FUNC_XORI:         alu_op <= `ALUOP_XOR;
                    `FUNC_SRLI_SRAI:    alu_op <= dec_funct7[5] ? `ALUOP_SRA : `ALUOP_SRL;
                    `FUNC_ORI:          alu_op <= `ALUOP_OR;
                    `FUNC_ANDI:         alu_op <= `ALUOP_AND;
                    default:            alu_op <= `ALUOP_ADD;
                endcase
                nextstate <= STATE_REGWRITEALU;
            end

            STATE_LOAD1: begin // compute load address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                nextstate <= STATE_LOAD2;
            end

            STATE_LOAD2: begin // load from computed address
                bus_en <= 1;
                mux_bus_addr_sel <= MUX_BUSADDR_ALU;
                case(dec_funct3)
                    `FUNC_LB:   bus_op <= `BUSOP_READB;
                    `FUNC_LH:   bus_op <= `BUSOP_READH;
                    `FUNC_LW:   bus_op <= `BUSOP_READW;
                    `FUNC_LBU:  bus_op <= `BUSOP_READBU;
                    default:    bus_op <= `BUSOP_READHU; // FUNC_LHU
                endcase
                nextstate <= STATE_REGWRITEBUS;
            end

            STATE_STORE1: begin // compute store address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                nextstate <= STATE_STORE2;
            end

            STATE_STORE2: begin // store to computed address
                bus_en <= 1;
                mux_bus_addr_sel <= MUX_BUSADDR_ALU;
                case(dec_funct3)
                    `FUNC_SB:   bus_op <= `BUSOP_WRITEB;
                    `FUNC_SH:   bus_op <= `BUSOP_WRITEH;
                    default:    bus_op <= `BUSOP_WRITEW; // FUNC_SW
                endcase
                nextstate <= STATE_PCNEXT;
            end

            STATE_JAL_JALR1: begin // compute return address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_INSTLEN;
                nextstate <= STATE_JAL_JALR2;
            end

            STATE_JAL_JALR2: begin // write return address to register file
                reg_we <= 1;
                mux_reg_input_sel <= MUX_REGINPUT_ALU;
                nextstate <= (dec_opcode[1]) ? STATE_PCIMM : STATE_PCREGIMM;
            end

            STATE_BRANCH1: begin // use ALU for comparisons
                alu_en <= 1;
                alu_op <= `ALUOP_ADD; // doesn't really matter
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_REGVAL2;
                nextstate <= STATE_BRANCH2;
            end

            STATE_BRANCH2: begin
                nextstate <= STATE_PCNEXT; // by default assume we don't branch
                case(dec_funct3)
                    `FUNC_BEQ:  if(alu_eq)   nextstate <= STATE_PCIMM;
                    `FUNC_BNE:  if(!alu_eq)  nextstate <= STATE_PCIMM;
                    `FUNC_BLT:  if(alu_lt)   nextstate <= STATE_PCIMM;
                    `FUNC_BGE:  if(!alu_lt)  nextstate <= STATE_PCIMM;
                    `FUNC_BLTU: if(alu_ltu)  nextstate <= STATE_PCIMM;
                    default:    if(!alu_ltu) nextstate <= STATE_PCIMM; // FUNC_BGEU
                endcase
            end

            STATE_LUI: begin
                reg_we <= 1;
                mux_reg_input_sel <= MUX_REGINPUT_IMM;
                nextstate <= STATE_PCNEXT;
            end

            STATE_AUIPC: begin // compute PC + IMM on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                nextstate <= STATE_REGWRITEALU;
            end

            STATE_SYSTEM: begin
                nextstate <= STATE_TRAP1;
                case(dec_funct3)
                    `FUNC_ECALL_EBREAK: begin
                        // handle ecall, ebreak and mret here
                        case(dec_imm[11:0])
                            `SYSTEM_ECALL: mcause <= CAUSE_ECALL;
                            `SYSTEM_EBREAK: mcause <= CAUSE_BREAK;
                            `SYSTEM_MRET: begin
                                meie <= meie_prev;
                                pc <= epc;
                                mcause <= 0;
                                nextstate <= STATE_FETCH;
                            end
                            default: mcause <= CAUSE_INVALID_INSTRUCTION;
                        endcase
                    end

                    `FUNC_CSRRW: begin
                        // handle csrrw here
                        nextstate <= STATE_CSRRW1;
                    end

                    // unsupported SYSTEM instruction
                    default: mcause <= CAUSE_INVALID_INSTRUCTION;
                endcase
            end

            STATE_TRAP1: begin
                meie_prev <= meie;
                meie <= 0;
                epc <= pc;
                pc <= evect;

                nextstate <= STATE_FETCH;
            end

            STATE_CSRRW1: begin
                // write MSR-value to register
                mux_reg_input_sel <= MUX_REGINPUT_MSR;
                reg_we <= 1;
                nextstate <= STATE_CSRRW2;
            end

            STATE_CSRRW2: begin
                // update MSRs with value of rs1
                if(!dec_imm[11]) begin // denotes a writable non-standard machine-mode MSR
                    case(dec_imm[1:0])
                        MSR_CAUSE: mcause <= {reg_val1[31], reg_val1[3:0]};
                        MSR_EPC:   epc <= reg_val1;
                        MSR_MSTATUS: begin
                            meie <= reg_val1[0];
                            meie_prev <= reg_val1[1];
                        end
                        MSR_EVECT: evect <= reg_val1;
                    endcase
                end
                nextstate <= STATE_PCNEXT;
            end


            STATE_REGWRITEBUS: begin
                reg_we <= 1;
                mux_reg_input_sel <= MUX_REGINPUT_BUS;
                nextstate <= STATE_PCNEXT;
            end

            STATE_REGWRITEALU: begin
                reg_we <= 1;
                mux_reg_input_sel <= MUX_REGINPUT_ALU;
                nextstate <= STATE_PCNEXT;
            end

            STATE_PCNEXT: begin // compute PC + INSTLEN
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_INSTLEN;
                nextstate <= STATE_PCUPDATE_FETCH;
            end

            STATE_PCREGIMM: begin // compute REGVAL1 + IMM
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                nextstate <= STATE_PCUPDATE_FETCH;
            end

            STATE_PCIMM: begin // compute PC + IMM
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                nextstate <= STATE_PCUPDATE_FETCH;
            end

            STATE_PCUPDATE_FETCH: begin
                // update PC with computed address
                pc <= alu_dataout;

                // ALU output is address of next instruction. Go fetch!
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= MUX_BUSADDR_ALU;
                nextstate <= STATE_DECODE;
            end

        endcase


        if(reset) begin
            prevstate <= STATE_RESET;
            nextstate <= STATE_RESET;
        end


    end



endmodule