`default_nettype none

`include "./cpu/alu.v"
`include "./cpu/branch.v"
`include "./cpu/bus.v"
`include "./cpu/decoder.v"
`include "./cpu/registers.v"


module spu32_cpu
    #(
        parameter VECTOR_RESET = 32'd0,
        parameter VECTOR_EXCEPTION = 32'd16
    )
    (
        input I_clk,
        input I_reset,
        input I_wait,
        input I_interrupt,
        input[31:0] I_data,
        output[31:0] O_data,
        output[31:0] O_addr,
        output O_strobe,
        output O_write,
        output O_halfword,
        output O_fullword
    );

    wire clk, reset;
    assign clk = I_clk;
    assign reset = I_reset;

    // MSRS
    reg[31:2] pc, pc_alu, pcnext, epc;
    reg[31:2] evect = VECTOR_EXCEPTION[31:2];
    reg nextpc_from_alu, nextpc_from_bru, writeback_in_fetch;
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
    wire[31:0] alu_dataout;
    reg[31:0] alu_dataS1, alu_dataS2;
    wire alu_busy, alu_lt, alu_ltu, alu_eq;

    spu32_cpu_alu alu_inst(
        .I_clk(clk),
        .I_en(alu_en),
        .I_reset(reset),
        .I_dataS1(alu_dataS1),
        .I_dataS2(alu_dataS2),
        .I_aluop(dec_aluop),
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

    wire[31:0] ntbus_dataout, ntbus_addr;
    wire ntbus_strobe, ntbus_write, ntbus_halfword, ntbus_fullword;
    spu32_cpu_bus bus_inst(
        .I_clk(clk),
        .I_en(bus_en),
        .I_op(bus_op),
        .I_data(reg_val2),
        .I_addr(bus_addr),
        .O_data(bus_dataout),
        .O_busy(bus_busy),
        // signals to outside world
        .O_bus_data(ntbus_dataout),
        .O_bus_addr(ntbus_addr),
        .O_bus_strobe(ntbus_strobe),
        .O_bus_write(ntbus_write),
        .O_bus_halfword(ntbus_halfword),
        .O_bus_fullword(ntbus_fullword),
        .I_bus_data(I_data),
        .I_bus_wait(I_wait)
    );

    assign O_data = ntbus_dataout;
    assign O_addr = ntbus_addr;
    assign O_strobe = ntbus_strobe;
    assign O_write = ntbus_write;
    assign O_halfword = ntbus_halfword;
    assign O_fullword = ntbus_fullword;



    // Decoder instance
    wire[4:0] dec_rs1, dec_rs2, dec_rd;
    wire[31:0] dec_imm;
    wire[4:0] dec_opcode;
    wire[2:0] dec_funct3;
    wire[5:0] dec_branchmask;
    wire[3:0] dec_aluop;
    wire[2:0] dec_busop;
    wire dec_alumux1, dec_alumux2, dec_writeback;
    wire[1:0] dec_reginputmux;
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
        .O_writeback(dec_writeback),
        .O_funct3(dec_funct3),
        .O_branchmask(dec_branchmask),
        .O_aluop(dec_aluop),
        .O_busop(dec_busop),
        .O_alumux1(dec_alumux1),
        .O_alumux2(dec_alumux2),
        .O_reginputmux(dec_reginputmux)
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

    reg bru_en = 0;
    reg bru_eval_branch = 0;
    wire[31:0] bru_nextpc;
    wire bru_misaligned;

    // Branch unit instance
    spu32_cpu_branch bru_inst(
        .I_clk(clk),
        .I_en(bru_en),
        .I_evaluate_branch(bru_eval_branch),
        .I_branchmask(dec_branchmask),
        .I_lt(alu_lt),
        .I_ltu(alu_ltu),
        .I_eq(alu_eq),
        .I_pc({pc, 2'b00}),
        .I_imm(dec_imm),
        .O_nextpc(bru_nextpc),
        .O_misaligned(bru_misaligned)
    );

    // Muxer for first operand of ALU
    localparam MUX_ALUDAT1_REGVAL1 = 0;
    localparam MUX_ALUDAT1_PC      = 1;
    always @(*) begin
        case(dec_alumux1)
            MUX_ALUDAT1_REGVAL1: alu_dataS1 = reg_val1;
            default:             alu_dataS1 = {pc_alu, 2'b00}; // MUX_ALUDAT1_PC
        endcase
    end

    // Muxer for second operand of ALU
    localparam MUX_ALUDAT2_REGVAL2 = 0;
    localparam MUX_ALUDAT2_IMM     = 1;
    always @(*) begin
        case(dec_alumux2)
            MUX_ALUDAT2_REGVAL2: alu_dataS2 = reg_val2;
            default:             alu_dataS2 = dec_imm; // MUX_ALUDAT_IMM
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
    assign mstatus32 = {{29{1'b0}}, I_interrupt, meie_prev, meie};

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
    localparam MUX_REGINPUT_BRU = 2;
    localparam MUX_REGINPUT_MSR = 3;
    always @(*) begin
        case(dec_reginputmux)
            MUX_REGINPUT_ALU: reg_datain = alu_dataout;
            MUX_REGINPUT_BUS: reg_datain = bus_dataout;
            MUX_REGINPUT_BRU: reg_datain = bru_nextpc;
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
    localparam STATE_CSRRW          = 8;

    reg[3:0] state, prevstate = STATE_RESET, nextstate = STATE_RESET;

    wire busy;
    assign busy = alu_busy | bus_busy;

    // only transition to new state if not busy    
    always @(*) begin
        state = busy ? prevstate : nextstate;
    end

    always @(posedge clk) begin
        // posedge-registered copy of PC to avoid negedge -> posedge critical path in ALU
        pc_alu <= pc;
    end

    always @(negedge clk) begin

        alu_en <= 0;
        bru_en <= 0;
        bru_eval_branch <= 0;
        bus_en <= 0;
        dec_en <= 0;
        reg_re <= 0;
        reg_we <= 0;

        // remember currently active state to return to if busy
        prevstate <= state;

        case(state)
            STATE_RESET: begin
                pcnext <= VECTOR_RESET[31:2];
                evect <= VECTOR_EXCEPTION[31:2];
                meie <= 0; // disable machine-mode external interrupt
                nextstate <= STATE_FETCH;
                nextpc_from_alu <= 0;
                nextpc_from_bru <= 0;
                writeback_in_fetch <= 0;
            end

            STATE_FETCH: begin
                // write result of previous instruction to registers if requested
                reg_we <= writeback_in_fetch;
                writeback_in_fetch <= 0;

                // update PC
                // TODO: if alu_dataout contains a misaligned address, raise exception
                // instead of altering the PC.
                pc <= nextpc_from_alu ? alu_dataout[31:2] : pcnext[31:2];
                if(nextpc_from_bru) begin
                    pc <= bru_nextpc[31:2];
                end

                // fetch next instruction 
                bus_en <= 1;
                bus_op <= `BUSOP_READW;
                mux_bus_addr_sel <= MUX_BUSADDR_PC;
                nextstate <= STATE_DECODE;
            end

            STATE_DECODE: begin
                // assume for now the next PC will come from pcnext
                nextpc_from_alu <= 0;
                nextpc_from_bru <= 0;

                dec_en <= 1;
                nextstate <= STATE_EXEC;

                // read registers
                reg_re <= 1;

                // compute PC+4 on branch unit
                bru_en <= 1;

                // checking for interrupt here because no bus operations are active here
                // TODO: find a proper place that doesn't let an instruction fetch go to waste
                if(meie & I_interrupt) begin
                    mcause <= CAUSE_EXTERNAL_INTERRUPT;
                    nextstate <= STATE_TRAP1;
                end

            end

            STATE_EXEC: begin
                // PC+4 was computed on branch unit, save
                pcnext <= bru_nextpc[31:2];

                alu_en <= 1;
                writeback_in_fetch <= dec_writeback;

                case(dec_opcode)
                    `OP_OP, `OP_OPIMM, `OP_LUI, `OP_AUIPC: begin
                        nextstate <= STATE_FETCH;
                    end

                    `OP_LOAD, `OP_STORE: begin // compute load/store address on ALU
                        nextstate <= STATE_LOADSTORE;
                    end

                    `OP_JAL, `OP_JALR: begin
                        // return address computed in branch unit during decode, write to register
                        reg_we <= 1;

                        nextpc_from_alu <= 1;
                        nextstate <= STATE_FETCH;
                    end

                    `OP_BRANCH: begin // use ALU for comparisons
                        nextstate <= STATE_BRANCH2;
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
                //writeback_in_fetch <= (dec_opcode == `OP_LOAD);
                nextstate <= STATE_FETCH;
            end


            STATE_BRANCH2: begin
                // use branch unit to evaluate branch and compute branch target
                bru_en <= 1;
                bru_eval_branch <= 1;
                nextpc_from_bru <= 1;
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
                        // write current MSR-value to register, before modification
                        reg_we <= 1;
                        nextstate <= STATE_CSRRW;
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

            STATE_CSRRW: begin
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