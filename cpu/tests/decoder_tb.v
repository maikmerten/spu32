`include "./cpu/riscvdefs.vh"
`include "./cpu/decoder.v"

module decoder_tb;

    `include "./tb/tbcommon.v"	

    reg[31:0] instr;
    reg en = 0;
    wire[4:0] rs1, rs2, rd;
    wire[31:0] imm;
    wire[4:0] opcode;
    wire[2:0] funct3;
        
    spu32_cpu_decoder mut(
        .I_instr(instr),
        .I_clk(clk),
        .I_en(en),
        .O_rs1(rs1),
        .O_rs2(rs2),
        .O_rd(rd),
        .O_imm(imm),
        .O_opcode(opcode),
        .O_funct3(funct3)
    );
    
    initial begin
        $dumpfile("./cpu/tests/decoder_tb.lxt");
        $dumpvars(0, clk, en, error, instr, rs1, rs2, rd, imm, opcode, funct3);

        @(negedge clk)
        en <= 1;
        instr <= 32'h00f00313; // addi t1,x0,15
        @(negedge clk)
        if(rs1 !== `R0) error <= 1;
        if(rd !== `T1) error <= 2;
        if(imm !== 15) error <= 3;
        
        instr <= 32'h006282b3; // add t0,t0,t1
        @(negedge clk)
        if(rs1 !== `T0) error <= 4;
        if(rs2 !== `T1) error <= 5;
        if(rd !== `T0) error <= 6;

        instr <= 32'h00502e23; // sw t0,28(x0)
        @(negedge clk)
        if(rs1 !== `R0) error <= 7;
        if(rs2 !== `T0) error <= 8;
        if(imm !== 28) error <= 9;

        instr <= 32'he0502023; // sw t0,-512(x0)
        @(negedge clk)
        if(rs1 !== `R0) error <= 10;
        if(rs2 !== `T0) error <= 11;
        if(imm !== -512) error <= 12;

        instr <= 32'h01c02283; // lw t0,28(x0)
        @(negedge clk)
        if(rs1 !== `R0) error <= 13;
        if(rd !== `T0) error <= 14;
        if(imm !== 28) error <= 15;

        instr <= 32'hff1ff3ef; // jal x7,4 (from 0x14)
        @(negedge clk)
        if(rd !== `R7) error <= 16;
        if(imm !== -16) error <= 17;

        instr <= 32'hfec003e7; // jalr x7,x0,-20
        @(negedge clk)
        if(rs1 !== `R0) error <= 18;
        if(rd !== `R7) error <= 19;
        if(imm != -20) error <= 20;

        instr <= 32'hf0f0f2b7; // lui t0,0xf0f0f
        @(negedge clk)
        if(rs1 !== `R1) error <= 21;
        if(rd !== `T0) error <= 22;
        if(imm !== 32'hf0f0f000) error <= 23;


        instr <= 32'hfe7316e3; // bne t1,t2,4 (from 0x18)
        @(negedge clk)
        if(rs1 !== `T1) error <= 24;
        if(rs2 !== `T2) error <= 25;
        if(imm !== -20) error <= 26;

        instr <= 32'hc0002373; // rdcycle t1
        @(negedge clk)
        if(rs1 !== `R0) error <= 27;
        if(rs2 !== `R0) error <= 28;

        instr = 32'hc80023f3; // rdcycleh t1
        @(negedge clk)
        if(rs1 !== `R0) error <= 29;
        if(rs2 !== `R0) error <= 30;

        
        #(3 * CLKPERIOD);
        $finish;
        
    end
            
    
endmodule
