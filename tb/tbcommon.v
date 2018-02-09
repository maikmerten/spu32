`ifndef TBCOMMON
	`define TBCOMMON 1

	parameter CLKPERIOD = 2;

	reg clk = 0;
	always # (CLKPERIOD / 2) clk = !clk;
	
	integer error = 0;
	always @(error) begin
		if(error !== 0) begin
			$display("!!! FINISHING WITH ERROR, TESTCASE %0d FAILED!", error);
			# (CLKPERIOD * 2);
			$finish_and_return(1);
		end
	end

`endif

