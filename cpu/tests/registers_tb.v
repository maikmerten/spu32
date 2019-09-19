`include "./cpu/registers.v"

module registers_tb;
    `include "./tb/tbcommon.v"
    
    reg[31:0] data = 0;
    reg[4:0] rs1, rs2, rd;
    reg re, we;
    wire[31:0] regval1, regval2;
        
    spu32_cpu_registers reginstance(
        .I_clk(clk),
        .I_data(data),
        .I_rs1(rs1),
        .I_rs2(rs2),
        .I_rd(rd),
        .I_re(re),
        .I_we(we),
        .O_regval1(regval1),
        .O_regval2(regval2)
    );
    
    initial begin
        $dumpfile("./cpu/tests/registers_tb.lxt");
        $dumpvars(0, clk, data, rs1, rs2, rd, re, we, regval1, regval2, error);

        // register 0 cannot be written to, is always zero	
        @(negedge clk);
        data = 32'hFEFE;
        rs1 = 0;
        rs2 = 0;
        rd = 0;
        re = 1;
        we = 1;
        @(negedge clk);
        we = 0;
        @(negedge clk);
        if(!(regval1 == 0)) error <= 1;

        // write a value into register 1		
        data = 32'hBEEF;
        rd = 1;
        we = 1;
        @(negedge clk);
        we = 0;
        rs2 = 1;
        // and ensure the value can be read back
        @(negedge clk);
        if(regval2 != 32'hBEEF) error <= 2;

        // ensure output value stays stable even after register write
        re = 0;
        we = 1;
        data = 32'hFEFE;
        @(negedge clk);
        if(regval2 != 32'hBEEF) error <= 3;

        // now read again
        re = 1;
        we = 0;
        @(negedge clk);
        if(regval2 != 32'hFEFE) error <= 4;
        
        
        
        #(3 * CLKPERIOD);
        $finish;
        
    end
            
    
endmodule
