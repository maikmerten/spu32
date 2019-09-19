`include "./cpu/aludefs.vh"
`include "./cpu/alu.v"

module alu_tb;
    `include "./tb/tbcommon.v"
    
    reg en = 0;
    reg reset = 0;
    reg[31:0] dataS1, dataS2;
    reg[3:0] aluop;
    wire busy, lt, ltu, eq;
    wire[31:0] data;
        
    spu32_cpu_alu mut(
        .I_clk(clk),
        .I_en(en),
        .I_reset(reset),
        .I_dataS1(dataS1),
        .I_dataS2(dataS2),
        .I_aluop(aluop),
        .O_busy(busy),
        .O_data(data),
        .O_lt(lt),
        .O_ltu(ltu),
        .O_eq(eq)
    );
    
    initial begin
        $dumpfile("./cpu/tests/alu_tb.lxt");
        $dumpvars(0, error, clk, en, reset, dataS1, dataS2, aluop, busy, data, lt, ltu, eq);

        // testcase 1			
        @(negedge clk);
        en = 1;
        aluop = `ALUOP_ADD;
        dataS1 = 40;
        dataS2 = 2;
        @(negedge clk);
        if(data !== 42) error <= 1;

        // testcase 2
        dataS1 = 44;
        dataS2 = -2;
        @(negedge clk);
        if(data !== 42) error <= 2;

        // testcase 3
        dataS1 = 1;
        dataS2 = 3;
        aluop = `ALUOP_SLL;	
        @(negedge busy);
        @(negedge clk);
        if(data !== 8) error <= 3;

        // testcase 4
        dataS1 = 32'hFFFFFFFF;
        dataS2 = 8;
        aluop = `ALUOP_SRL;
        @(negedge busy);
        @(negedge clk);
        if(data !== 32'h00FFFFFF) error <= 4;

        // testcase 5
        dataS1 = 32'h80000000;
        dataS2 = 3;
        aluop = `ALUOP_SRA;
        @(negedge busy);
        @(negedge clk);
        if(data != 32'hF0000000) error <= 5;

        // testcase 6, 7, 8
        dataS1 = 1337;
        dataS2 = 1337;
        aluop = `ALUOP_ADD;
        @(negedge clk);
        if(eq !== 1) error <= 6;
        if(lt !== 0) error <= 7;
        if(ltu !== 0) error <= 8;

        // testcase 9, 10, 11
        dataS1 = -5;
        dataS2 = 5;
        aluop = `ALUOP_ADD;
        @(negedge clk);
        if(eq !== 0) error <= 9;
        if(lt !== 1) error <= 10;
        if(ltu !== 0) error <= 11;

        // testcase 12, 13, 14
        dataS1 = 5;
        dataS2 = -5;
        aluop = `ALUOP_ADD;
        @(negedge clk);
        if(eq !== 0) error <= 12;
        if(lt !== 0) error <= 13;
        if(ltu !== 1) error <= 14;

        // testcase 15
        dataS1 = 32'h000000FF;
        dataS2 = 32'h00000FFF;
        aluop = `ALUOP_XOR;
        @(negedge clk);
        if(data !== 32'h00000F00) error <= 15;

        // testcase 16
        dataS1 = 32'h000000FF;
        dataS2 = 32'h00000FFF;
        aluop = `ALUOP_OR;
        @(negedge clk);
        if(data !== 32'h00000FFF) error <= 16;

        // testcase 17
        dataS1 = 32'h000000FF;
        dataS2 = 32'h00000FFF;
        aluop = `ALUOP_AND;
        @(negedge clk);
        if(data !== 32'h000000FF) error <= 17;

        // testcase 18
        dataS1 = 8;
        dataS2 = -2;
        aluop = `ALUOP_SUB;
        @(negedge clk);
        if(data != 10) error <= 18;

        // testcase 19
        dataS1 = -2;
        dataS2 = 13;
        aluop = `ALUOP_SUB;
        @(negedge clk);
        if(data != -15) error <= 19;

        // testcase 20
        dataS1 = 1337;
        dataS2 = 337;
        aluop = `ALUOP_SUB;
        @(negedge clk);
        if(data != 1000) error <= 20;
        
        
        #(3 * CLKPERIOD);
        $finish;
        
    end
            
    
endmodule
