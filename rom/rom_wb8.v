module rom_wb8
	#(
		parameter ROMINITFILE = "./rom/rominit.dat"
	)
	(
		input CLK_I,
		input STB_I,
		input[8:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O
	);


	reg[7:0] rom [511:0];
	
	initial $readmemh(ROMINITFILE, rom, 0, 511);

	always @(posedge CLK_I) begin
		DAT_O <= rom[ADR_I];
    	ACK_O <= STB_I;
	end

endmodule