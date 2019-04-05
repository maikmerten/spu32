module bram_wb8_vga
	#(
		parameter ADDRBITS = 13, // by default, 8 KB of BRAM
		parameter RAMINITFILE = "./ram/raminit.dat"
	)
	(
		input CLK_I,
		input STB_I,
		input WE_I,
		input[ADDRBITS-1:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O,
		output STALL_O,

		// read port for VGA
		input VGA_REQ_I,
		input[ADDRBITS-1:0] VGA_ADR_I
	);

	localparam RAMSIZE = 2**ADDRBITS;

	reg[7:0] ram [RAMSIZE-1:0];
	
	initial $readmemh(RAMINITFILE, ram, 0, RAMSIZE-1);

	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I;

	assign STALL_O = STB_I & VGA_REQ_I;

	always @(posedge CLK_I) begin
		if(write) ram[ADR_I] <= DAT_I;
		if(read) DAT_O <= ram[ADR_I];

		ACK_O <= (STB_I & !VGA_REQ_I);

	end

endmodule