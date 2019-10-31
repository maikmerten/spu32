`include "./cpu/alu.v"
`include "./cpu/bus_wb8.v"
`include "./cpu/decoder.v"
`include "./cpu/registers.v"


module spu32_cpu
    #(
        parameter VECTOR_RESET = 32'd0,
        parameter VECTOR_EXCEPTION = 32'd16
    )
    (
        input CLK_I,
        input ACK_I,
        input STALL_I,
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
    reg[31:2] pc, pcnext, epc;
    reg[31:2] evect = VECTOR_EXCEPTION[31:2];
    reg nextpc_from_alu, writeback_from_alu, writeback_from_bus;
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

    spu32_cpu_alu alu_inst(
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
    spu32_cpu_bus_wb8 bus_inst(
        .I_en(bus_en),
        .I_op(bus_op),
        .I_data(reg_val2),
        .I_addr(bus_addr),
        .O_data(bus_dataout),
        .O_busy(bus_busy),

        .CLK_I(clk),
        .ACK_I(ACK_I),
        .STALL_I(STALL_I),
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
    wire[5:0] dec_branchmask;
    wire[3:0] dec_aluop;
    wire[2:0] dec_busop;
    reg dec_en;

    spu32_cpu_decoder dec_inst(
        .I_clk(clk),
        .I_en(dec_en),
        .I_instr(bus_dataout),
        .O_rs1(dec_rs1),
        .O_rs2(dec_rs2),
        .O_rd(dec_rd),
        .O_imm(dec_imm),
        .O_opcode(dec_opcode),
        .O_funct3(dec_funct3),
        .O_branchmask(dec_branchmask),
        .O_aluop(dec_aluop),
        .O_busop(dec_busop)
    );

    // Registers instance
    spu32_cpu_registers reg_inst(
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
            default:             alu_dataS1 = {pc, 2'b00}; // MUX_ALUDAT1_PC
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
            default:         bus_addr = {pc, 2'b00}; // MUX_BUSADDR_PC
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
            MSR_EPC:     msr_data = {epc, 2'b00};
            default:     msr_data = {evect, 2'b00};
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
    localparam STATE_EXEC           = 3;
    localparam STATE_LOADSTORE      = 4;
    localparam STATE_BRANCH2        = 5;
    localparam STATE_TRAP1          = 6;
    localparam STATE_SYSTEM         = 7;
    localparam STATE_CSRRW1         = 8;
    localparam STATE_CSRRW2         = 9;


    reg[3:0] state, prevstate = STATE_RESET, nextstate = STATE_RESET;

    wire busy;
    assign busy = alu_busy | bus_busy;

    // evaluate branch conditions
    wire branch;
    assign branch = (dec_branchmask & {!alu_ltu, alu_ltu, !alu_lt, alu_lt, !alu_eq, alu_eq}) != 0;


    // only transition to new state if not busy    
    always @(*) begin
        state = busy ? prevstate : nextstate;
    end

    always @(negedge clk) begin

        alu_en <= 0;
        bus_en <= 0;
        dec_en <= 0;
        reg_re <= 0;
        reg_we <= 0;

        mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
        mux_alu_s2_sel <= MUX_ALUDAT2_REGVAL2;
        mux_reg_input_sel <= MUX_REGINPUT_ALU;

        alu_op <= `ALUOP_ADD;

        // remember currently active state to return to if busy
        prevstate <= state;

        case(state)
            STATE_RESET: begin
                pcnext <= VECTOR_RESET[31:2];
                evect <= VECTOR_EXCEPTION[31:2];
                meie <= 0; // disable machine-mode external interrupt
                nextstate <= STATE_FETCH;
                nextpc_from_alu <= 0;
                writeback_from_alu <= 0;
                writeback_from_bus <= 0;
            end

            STATE_FETCH: begin
                // write result of previous instruction to registers if requested
                mux_reg_input_sel <= writeback_from_alu ? MUX_REGINPUT_ALU : MUX_REGINPUT_BUS;
                reg_we <= writeback_from_alu | writeback_from_bus;
                writeback_from_alu <= 0;
                writeback_from_bus <= 0;

                // update PC
                // TODO: if alu_dataout contains a misaligned address, raise exception
                // instead of altering the PC.
                pc <= nextpc_from_alu ? alu_dataout[31:2] : pcnext[31:2];

                // fetch next instruction 
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= MUX_BUSADDR_PC;
                nextstate <= STATE_DECODE;
            end

            STATE_DECODE: begin
                // assume for now the next PC will come from pcnext
                nextpc_from_alu <= 0;

                dec_en <= 1;
                nextstate <= STATE_EXEC;

                // read registers
                reg_re <= 1;

                // ALU is unused... let's compute PC+4!
                alu_en <= 1;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_INSTLEN;

                // checking for interrupt here because no bus operations are active here
                // TODO: find a proper place that doesn't let an instruction fetch go to waste
                if(meie & INTERRUPT_I) begin
                    mcause <= CAUSE_EXTERNAL_INTERRUPT;
                    nextstate <= STATE_TRAP1;
                end

            end

            STATE_EXEC: begin
                // ALU output when coming from decode is PC+4... store it in pcnext
                if(!busy) pcnext <= alu_dataout[31:2];

                case(dec_opcode)
                    `OP_OP, `OP_OPIMM: begin
                        alu_en <= 1;
                        mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                        mux_alu_s2_sel <= (dec_opcode[3]) ? MUX_ALUDAT2_REGVAL2 : MUX_ALUDAT2_IMM;
                        alu_op <= dec_aluop;
                        // do register writeback in FETCH
                        writeback_from_alu <= 1;
                        nextstate <= STATE_FETCH;
                    end

                    `OP_LOAD, `OP_STORE: begin // compute load/store address on ALU
                        alu_en <= 1;
                        alu_op <= `ALUOP_ADD;
                        mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                        mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                        nextstate <= STATE_LOADSTORE;
                    end

                    `OP_JAL, `OP_JALR: begin
                        // return address computed during decode, write to register
                        reg_we <= 1;
                        mux_reg_input_sel <= MUX_REGINPUT_ALU;

                        // compute jal/jalr address
                        alu_en <= 1;
                        alu_op <= `ALUOP_ADD;
                        mux_alu_s1_sel <= (dec_opcode[1]) ? MUX_ALUDAT1_PC : MUX_ALUDAT1_REGVAL1;
                        mux_alu_s2_sel <= MUX_ALUDAT2_IMM;

                        nextpc_from_alu <= 1;
                        nextstate <= STATE_FETCH;
                    end

                    `OP_BRANCH: begin // use ALU for comparisons
                        alu_en <= 1;
                        alu_op <= `ALUOP_ADD; // doesn't really matter
                        mux_alu_s1_sel <= MUX_ALUDAT1_REGVAL1;
                        mux_alu_s2_sel <= MUX_ALUDAT2_REGVAL2;
                        nextstate <= STATE_BRANCH2;
                    end

                    `OP_AUIPC: begin // compute PC + IMM on ALU
                        alu_en <= 1;
                        alu_op <= `ALUOP_ADD;
                        mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                        mux_alu_s2_sel <= MUX_ALUDAT2_IMM;
                        // do register writeback in FETCH
                        writeback_from_alu <= 1;
                        nextstate <= STATE_FETCH;
                    end

                    `OP_LUI: begin
                        reg_we <= 1;
                        mux_reg_input_sel <= MUX_REGINPUT_IMM;
                        nextstate <= STATE_FETCH;
                    end

                    `OP_MISCMEM:    nextstate <= STATE_FETCH; // nop
                    `OP_SYSTEM:     nextstate <= STATE_SYSTEM;
                    default:        nextstate <= STATE_TRAP1;
                endcase
            end


            STATE_LOADSTORE: begin // load from computed address
                bus_en <= 1;
                mux_bus_addr_sel <= MUX_BUSADDR_ALU;
                bus_op <= dec_busop;
                //writeback_from_bus <= !dec_opcode[3];
                writeback_from_bus <= (dec_opcode == `OP_LOAD);
                nextstate <= STATE_FETCH;
            end


            STATE_BRANCH2: begin
                // use idle ALU to compute PC+immediate - in case we branch
                alu_en <= 1;
                alu_op <= `ALUOP_ADD;
                mux_alu_s1_sel <= MUX_ALUDAT1_PC;
                mux_alu_s2_sel <= MUX_ALUDAT2_IMM;

                nextpc_from_alu <= branch;
                nextstate <= STATE_FETCH;
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
                                pcnext <= epc;
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
                pcnext <= evect;

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
                        MSR_EPC:   epc <= reg_val1[31:2];
                        MSR_MSTATUS: begin
                            meie <= reg_val1[0];
                            meie_prev <= reg_val1[1];
                        end
                        MSR_EVECT: evect <= reg_val1[31:2];
                    endcase
                end
                // advance to next instruction
                nextstate <= STATE_FETCH;
            end

        endcase


        if(reset) begin
            prevstate <= STATE_RESET;
            nextstate <= STATE_RESET;
        end


    end



endmodule