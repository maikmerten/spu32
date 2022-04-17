`default_nettype none
`include "./cpu/div.v"

// This testbench uses test vectors taken from "risc-v compliance."
// "risc-compliance" is licensed as follows:
/*
# Copyright (c) 2018, Imperas Software Ltd.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#      * Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#      * Neither the name of the Imperas Software Ltd. nor the
#        names of its contributors may be used to endorse or promote products
#        derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Imperas Software Ltd. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

module div_tb;
    `include "./tb/tbcommon.v"
    
    reg en = 0;
    reg reset = 0;
    reg divide = 1;
    reg sign = 0;
    reg[31:0] dataS1, dataS2;
    wire busy;
    wire[31:0] result;
        
    spu32_cpu_div mut(
        .I_clk(clk),
        .I_en(en),
        .I_reset(reset),
        .I_dividend(dataS1),
        .I_divisor(dataS2),
        .I_divide(divide),
        .I_signed_op(sign),
        .O_busy(busy),
        .O_result(result)
    );

    reg[31:0] testnum = 0;
    task div;
        input[31:0] expected, s1, s2;
        begin
            @(negedge clk);
            en = 1;
            divide = 1;
            sign = 1;
            dataS1 = s1;
            dataS2 = s2;
            @(negedge busy);
            en = 0;
            $display("div: %d / %d = %d", $signed(s1), $signed(s2), $signed(result));
            testnum = testnum + 1;
            if(result != expected) error <= testnum;
        end
    endtask

    task divu;
        input[31:0] expected, s1, s2;
        begin
            @(negedge clk);
            en = 1;
            divide = 1;
            sign = 0;
            dataS1 = s1;
            dataS2 = s2;
            @(negedge busy);
            en = 0;
            $display("divu: %d / %d = %d", s1, s2, result);
            testnum = testnum + 1;
            if(result != expected) error <= testnum;
        end
    endtask

    task rem;
        input[31:0] expected, s1, s2;
        begin
            @(negedge clk);
            en = 1;
            divide = 0;
            sign = 1;
            dataS1 = s1;
            dataS2 = s2;
            @(negedge busy);
            en = 0;
            $display("rem: %d %% %d = %d", $signed(s1), $signed(s2), $signed(result));
            testnum = testnum + 1;
            if(result != expected) error <= testnum;
        end
    endtask

    task remu;
        input[31:0] expected, s1, s2;
        begin
            @(negedge clk);
            en = 1;
            divide = 0;
            sign = 0;
            dataS1 = s1;
            dataS2 = s2;
            @(negedge busy);
            en = 0;
            $display("remu: %d %% %d = %d", s1, s2, result);
            testnum = testnum + 1;
            if(result != expected) error <= testnum;
        end
    endtask

    task looptest;
        reg[16:0] i;
        reg[7:0] hi, lo;
        reg[31:0] a, b, divu_expected, rem_expected;
        reg signed[31:0] div_expected, remu_expected;
        begin
            for(i = 0; !i[16]; i = i + 1) begin
                hi = i[15:8];
                lo = i[7:0];
                a = {hi[7:5], {25{hi[4]}}, hi[3:0]};
                b = {lo[7:5], {25{lo[4]}}, lo[3:0]};

                if(b == 0) begin 
                    div_expected = 32'hffffffff;
                    divu_expected = 32'hffffffff;
                    rem_expected = a;
                    remu_expected = a;
                end else begin
                    div_expected = $signed(a) / $signed(b);
                    divu_expected = a / b;
                    rem_expected = $signed(a) % $signed(b);
                    remu_expected = a % b;
                end

                div(div_expected, a, b);
                rem(rem_expected, a, b);
                divu(divu_expected, a, b);
                remu(remu_expected, a, b);
            end
            
        end
    endtask
    
    initial begin
        $dumpfile("./cpu/tests/div_tb.lxt");
        $dumpvars(0, mut);

        // test vectors from riscv-compliance, DIV.S

        div(32'hffffffff, 0, 0);
        div(0, 0, 1);
        div(0, 0, -1);
        div(0, 0, 32'h7fffffff);
        div(0, 0, 32'h80000000);

        div(32'hffffffff, 1, 0);
        div(1, 1, 1);
        div(32'hffffffff, 1, -1);
        div(0, 1, 32'h7fffffff);
        div(0, 1, 32'h80000000);

        div(32'hffffffff, -1, 0);
        div(32'hffffffff, -1, 1);
        div(1, -1, -1);
        div(0, -1, 32'h7fffffff);
        div(0, -1, 32'h80000000);

        div(32'hffffffff, 32'h7fffffff, 0);
        div(32'h7fffffff, 32'h7fffffff, 1);
        div(32'h80000001, 32'h7fffffff, -1);
        div(1, 32'h7fffffff, 32'h7fffffff);
        div(0, 32'h7fffffff, 32'h80000000);

        div(32'hffffffff, 32'h80000000, 0);
        div(32'h80000000, 32'h80000000, 1);
        div(32'h80000000, 32'h80000000, -1);
        div(32'hffffffff, 32'h80000000, 32'h7fffffff);
        div(1, 32'h80000000, 32'h80000000);

        // test vectors from riscv-compliance, DIVU.S

        divu(32'hffffffff, 0, 0);
        divu(0, 0, 1);
        divu(0, 0, -1);
        divu(0, 0, 32'h7fffffff);
        divu(0, 0, 32'h80000000);

        divu(32'hffffffff, 1, 0);
        divu(1, 1, 1);
        divu(0, 1, -1);
        divu(0, 1, 32'h7fffffff);
        divu(0, 1, 32'h80000000);

        divu(32'hffffffff, -1, 0);
        divu(32'hffffffff, -1, 1);
        divu(1, -1, -1);
        divu(2, -1, 32'h7fffffff);
        divu(1, -1, 32'h80000000);

        divu(32'hffffffff, 32'h7fffffff, 0);
        divu(32'h7fffffff, 32'h7fffffff, 1);
        divu(0, 32'h7fffffff, -1);
        divu(1, 32'h7fffffff, 32'h7fffffff);
        divu(0, 32'h7fffffff, 32'h80000000);

        divu(32'hffffffff, 32'h80000000, 0);
        divu(32'h80000000, 32'h80000000, 1);
        divu(0, 32'h80000000, -1);
        divu(1, 32'h80000000, 32'h7fffffff);
        divu(1, 32'h80000000, 32'h80000000);

        // test vectors from riscv-compliance, REM.S

        rem(0, 0, 0);
        rem(0, 0, 1);
        rem(0, 0, -1);
        rem(0, 0, 32'h7fffffff);
        rem(0, 0, 32'h80000000);

        rem(1, 1, 0);
	    rem(0, 1, 1);
	    rem(0, 1, -1);
	    rem(1, 1, 32'h7fffffff);
	    rem(1, 1, 32'h80000000); // FAIL

	    rem(32'hffffffff, -1, 0);
	    rem(0, -1, 1);
	    rem(0, -1, -1);
	    rem(32'hffffffff, -1, 32'h7fffffff);
	    rem(32'hffffffff, -1, 32'h80000000);

	    rem(32'h7fffffff, 32'h7fffffff, 0);
	    rem(0, 32'h7fffffff, 1);
	    rem(0, 32'h7fffffff, -1);
	    rem(0, 32'h7fffffff, 32'h7fffffff);
	    rem(32'h7fffffff, 32'h7fffffff, 32'h80000000);

	    rem(32'h80000000, 32'h80000000, 0);
	    rem(0, 32'h80000000, 32'h1);
	    rem(0, 32'h80000000, -1);
	    rem(32'hffffffff, 32'h80000000, 32'h7fffffff);
	    rem(0, 32'h80000000, 32'h80000000);

        // test vectors from riscv-compliance, REMU.S

        remu(0, 0, 0);
	    remu(0, 0, 1);
	    remu(0, 0, -1);
	    remu(0, 0, 32'h7fffffff);
	    remu(0, 0, 32'h80000000);

        remu(1, 1, 0);
	    remu(0, 1, 1);
	    remu(1, 1, -1);
	    remu(1, 1, 32'h7fffffff);
	    remu(1, 1, 32'h80000000);

        remu(32'hffffffff, -1, 0);
	    remu(0, -1, 1);
	    remu(0, -1, -1);
	    remu(1, -1, 32'h7fffffff);
	    remu(32'h7fffffff, -1, 32'h80000000);

	    remu(32'h7fffffff, 32'h7fffffff, 0);
	    remu(0, 32'h7fffffff, 1);
	    remu(32'h7fffffff, 32'h7fffffff, -1);
	    remu(0, 32'h7fffffff, 32'h7fffffff);
	    remu(32'h7fffffff, 32'h7fffffff, 32'h80000000);

        remu(32'h80000000, 32'h80000000, 0);
	    remu(0, 32'h80000000, 1);
	    remu(32'h80000000, 32'h80000000, -1);
	    remu(1, 32'h80000000, 32'h7fffffff);
	    remu(0, 32'h80000000, 32'h80000000);

        looptest();

        #(3 * CLKPERIOD);
        $finish;
        
    end
            
    
endmodule
