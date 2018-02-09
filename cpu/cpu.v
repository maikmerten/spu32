`include "./cpu/alu.v"
`include "./cpu/bus_wb8.v"
`include "./cpu/decoder.v"
`include "./cpu/registers.v"
`include "./cpu/muxers.v"


module cpu(
    input CLK_I,
	input ACK_I,
	input[7:0] DAT_I,
	input RST_I,
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
    reg[31:0] instr, pc;

    // ALU instance
    reg alu_en = 0;
    reg[3:0] alu_op = 0;
    wire[31:0] alu_dataS1, alu_dataS2, alu_dataout;
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
    wire[31:0] bus_dataout, bus_addr;
    wire bus_busy;

    reg reg_we = 0, reg_re = 0;
    wire[31:0] reg_val1, reg_val2, reg_datain;

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
    reg mux_alu_s1_sel = 0;
    `define MUX_ALUDAT1_REGVAL1 0
    `define MUX_ALUDAT1_PC      1
    mux32x2 mux_alu_s1(
        .port0(reg_val1),
        .port1(pc),
        .sel(mux_alu_s1_sel),
        .out(alu_dataS1)
    );

    // Muxer for second operand of ALU
    reg[1:0] mux_alu_s2_sel = 0;
    `define MUX_ALUDAT2_REGVAL2 0
    `define MUX_ALUDAT2_IMM     1
    `define MUX_ALUDAT2_INSTLEN 2
    mux32x3 mux_alu_s2(
        .port0(reg_val2),
        .port1(dec_imm),
        .port2(4),
        .sel(mux_alu_s2_sel),
        .out(alu_dataS2)
    );

    // Muxer for bus address
    reg mux_bus_addr_sel = 0;
    `define MUX_BUSADDR_ALU 0
    `define MUX_BUSADDR_PC  1
    mux32x2 mux_bus_addr(
        .port0(alu_dataout),
        .port1(pc),
        .sel(mux_bus_addr_sel),
        .out(bus_addr)
    );

    // Muxer for register data input
    reg[1:0] mux_reg_input_sel = 0;
    `define MUX_REGINPUT_ALU    0
    `define MUX_REGINPUT_BUS    1
    `define MUX_REGINPUT_IMM    2
    mux32x3 mux_reg_input(
        .port0(alu_dataout),
        .port1(bus_dataout),
        .port2(dec_imm),
        .sel(mux_reg_input_sel),
        .out(reg_datain)
    );

    `define STATE_RESET             0
    `define STATE_FETCH             1
    `define STATE_DECODE            2
    `define STATE_REGREAD           3
    `define STATE_JAL_JALR1         4
    `define STATE_JAL_JALR2         5
    `define STATE_LUI               6
    `define STATE_AUIPC             7
    `define STATE_OP                8
    `define STATE_OPIMM             9
    `define STATE_STORE1            10
    `define STATE_STORE2            11
    `define STATE_LOAD1             12
    `define STATE_LOAD2             13
    `define STATE_BRANCH1           14
    `define STATE_BRANCH2           15
    `define STATE_TRAP1             16
    `define STATE_TRAP2             17
    `define STATE_REGWRITEBUS       18
    `define STATE_REGWRITEALU       19
    `define STATE_PCNEXT            20
    `define STATE_PCREGIMM          21
    `define STATE_PCIMM             22
    `define STATE_PCUPDATE_FETCH    23


    reg[4:0] state = 0, nextstate = 0;

    wire busy;
    assign busy = alu_busy | bus_busy;

    always @(negedge clk) begin

        alu_en <= 0;
        bus_en <= 0;
        reg_re <= 0;
        reg_we <= 0;

        mux_alu_s1_sel <= 0;
        mux_alu_s2_sel <= 0;
        mux_reg_input_sel <= 0;

        alu_op <= `ALUOP_ADD;

        if(!busy) state = nextstate; // assume new state NOW!
        

        case(state)
            `STATE_RESET: begin
                pc <= 0;
                nextstate <= `STATE_FETCH;
            end

            `STATE_FETCH: begin
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= `MUX_BUSADDR_PC;
                nextstate <= `STATE_DECODE;
            end

            `STATE_DECODE: begin
                instr <= bus_dataout;
                nextstate <= `STATE_REGREAD;
            end

            `STATE_REGREAD: begin
                reg_re <= 1;
                case(dec_opcode)
                    `OP_OP:         nextstate <= `STATE_OP;
                    `OP_OPIMM:      nextstate <= `STATE_OPIMM;
                    `OP_LOAD:       nextstate <= `STATE_LOAD1;
                    `OP_STORE:      nextstate <= `STATE_STORE1;
                    `OP_JAL:        nextstate <= `STATE_JAL_JALR1;
                    `OP_JALR:       nextstate <= `STATE_JAL_JALR1;
                    `OP_BRANCH:     nextstate <= `STATE_BRANCH1;
                    `OP_LUI:        nextstate <= `STATE_LUI;
                    `OP_AUIPC:      nextstate <= `STATE_AUIPC;
                    `OP_MISCMEM:    nextstate <= `STATE_PCNEXT; // nop
                    default:        nextstate <= `STATE_TRAP1;
                endcase
            end

            `STATE_OP: begin
                alu_en <= 1;
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_REGVAL2;
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
                nextstate <= `STATE_REGWRITEALU;
            end

            `STATE_OPIMM: begin
                alu_en <= 1;
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
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
                nextstate <= `STATE_REGWRITEALU;
            end

            `STATE_LOAD1: begin // compute load address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
                nextstate <= `STATE_LOAD2;
            end

            `STATE_LOAD2: begin // load from computed address
                bus_en <= 1;
                mux_bus_addr_sel <= `MUX_BUSADDR_ALU;
                case(dec_funct3)
                    `FUNC_LB:   bus_op <= `BUSOP_READB;
                    `FUNC_LH:   bus_op <= `BUSOP_READH;
                    `FUNC_LW:   bus_op <= `BUSOP_READW;
                    `FUNC_LBU:  bus_op <= `BUSOP_READBU;
                    `FUNC_LHU:  bus_op <= `BUSOP_READHU;
                endcase
                nextstate <= `STATE_REGWRITEBUS;
            end

            `STATE_STORE1: begin // compute store address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
                nextstate <= `STATE_STORE2;
            end

            `STATE_STORE2: begin // store to computed address
                bus_en <= 1;
                mux_bus_addr_sel <= `MUX_BUSADDR_ALU;
                case(dec_funct3)
                    `FUNC_SB:   bus_op <= `BUSOP_WRITEB;
                    `FUNC_SH:   bus_op <= `BUSOP_WRITEH;
                    `FUNC_SW:   bus_op <= `BUSOP_WRITEW;
                endcase
                nextstate <= `STATE_PCNEXT;
            end

            `STATE_JAL_JALR1: begin // compute return address on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= `MUX_ALUDAT2_INSTLEN;
                nextstate <= `STATE_JAL_JALR2;
            end

            `STATE_JAL_JALR2: begin // write return address to register file
                reg_we <= 1;
                mux_reg_input_sel <= `MUX_REGINPUT_ALU;
                nextstate <= (dec_opcode[1]) ? `STATE_PCIMM : `STATE_PCREGIMM;
            end

            `STATE_BRANCH1: begin // use ALU for comparisons
                alu_en <= 1;
                alu_op <= `ALUOP_ADD; // doesn't really matter
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_REGVAL2;
                nextstate <= `STATE_BRANCH2;
            end

            `STATE_BRANCH2: begin
                nextstate <= `STATE_PCNEXT; // by default assume we don't branch
                case(dec_funct3)
                    `FUNC_BEQ:  if(alu_eq)   nextstate <= `STATE_PCIMM;
                    `FUNC_BNE:  if(!alu_eq)  nextstate <= `STATE_PCIMM;
                    `FUNC_BLT:  if(alu_lt)   nextstate <= `STATE_PCIMM;
                    `FUNC_BGE:  if(!alu_lt)  nextstate <= `STATE_PCIMM;
                    `FUNC_BLTU: if(alu_ltu)  nextstate <= `STATE_PCIMM;
                    `FUNC_BGEU: if(!alu_ltu) nextstate <= `STATE_PCIMM;
                endcase
            end

            `STATE_LUI: begin
                reg_we <= 1;
                mux_reg_input_sel <= `MUX_REGINPUT_IMM;
                nextstate <= `STATE_PCNEXT;
            end

            `STATE_AUIPC: begin // compute PC + IMM on ALU
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
                nextstate <= `STATE_REGWRITEALU;
            end

            `STATE_TRAP1: nextstate <= `STATE_TRAP2; // TODO: do something proper her
            `STATE_TRAP2: nextstate <= `STATE_PCNEXT; // TODO: see above

            `STATE_REGWRITEBUS: begin
                reg_we <= 1;
                mux_reg_input_sel <= `MUX_REGINPUT_BUS;
                nextstate <= `STATE_PCNEXT;
            end

            `STATE_REGWRITEALU: begin
                reg_we <= 1;
                mux_reg_input_sel <= `MUX_REGINPUT_ALU;
                nextstate <= `STATE_PCNEXT;
            end

            `STATE_PCNEXT: begin // compute PC + INSTLEN
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= `MUX_ALUDAT2_INSTLEN;
                nextstate <= `STATE_PCUPDATE_FETCH;
            end

            `STATE_PCREGIMM: begin // compute REGVAL1 + IMM
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_REGVAL1;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
                nextstate <= `STATE_PCUPDATE_FETCH;
            end

            `STATE_PCIMM: begin // compute PC + IMM
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= `MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= `MUX_ALUDAT2_IMM;
                nextstate <= `STATE_PCUPDATE_FETCH;
            end

            `STATE_PCUPDATE_FETCH: begin
                // update PC with computed address
                pc <= alu_dataout;

                // ALU output is address of next instruction. Go fetch!
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= `MUX_BUSADDR_ALU;
                nextstate <= `STATE_DECODE;
            end

        endcase


        if(reset) begin
            state <= `STATE_RESET;
            nextstate <= `STATE_RESET;
        end


    end



endmodule