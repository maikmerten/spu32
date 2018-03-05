module ram1k_wb8
	#(
		parameter RAMINITFILE = "./ram/raminit.dat"
	)
	(
		input CLK_I,
		input STB_I,
		input WE_I,
		input[9:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output ACK_O
	);

	reg[7:0] ram [1023:0];
	
	initial $readmemh(RAMINITFILE, ram, 0, 1023);

	reg ack = 0;
	assign ACK_O = ack & STB_I;

	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I;

	always @(posedge CLK_I) begin
		ack <= 0;
		if(STB_I) ack <= 1;

		if(write) ram[ADR_I] <= DAT_I;
		if(read) DAT_O <= ram[ADR_I];
	end

endmodule