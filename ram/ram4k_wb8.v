module ram4k_wb8
	#(
		parameter RAMINITFILE = "./ram/raminit.dat"
	)
	(
		input CLK_I,
		input STB_I,
		input WE_I,
		input[11:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O
	);

	reg[7:0] ram [4095:0];
	
	initial $readmemh(RAMINITFILE, ram, 0, 4095);

	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I;

	always @(posedge CLK_I) begin
		if(write) ram[ADR_I] <= DAT_I;
		if(read) DAT_O <= ram[ADR_I];

		ACK_O <= STB_I;

	end

endmodule