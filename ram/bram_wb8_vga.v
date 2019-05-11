module bram_wb8_vga
	#(
		parameter ADDRBITS = 13, // by default, 8 KB of BRAM
		parameter RAMINITFILE = "./ram/raminit.dat"
	)
	(
		input I_wb_clk,
		input I_wb_stb,
		input I_wb_we,
		input[ADDRBITS-1:0] I_wb_adr,
		input[7:0] I_wb_dat,
		output reg [7:0] O_wb_dat,
		output reg O_wb_ack,
		output O_wb_stall,

		// read port for VGA
		input I_vga_req,
		input[ADDRBITS-1:0] I_vga_adr
	);

	localparam RAMSIZE = 2**ADDRBITS;

	reg[7:0] ram [RAMSIZE-1:0];
	
	initial $readmemh(RAMINITFILE, ram, 0, RAMSIZE-1);

	wire write = I_wb_stb & I_wb_we;
	wire read = I_wb_stb & !I_wb_we;

	assign O_wb_stall = I_wb_stb & I_vga_req;

	always @(posedge I_wb_clk) begin
		if(write) ram[I_wb_adr] <= I_wb_dat;
		if(read) O_wb_dat <= ram[I_wb_adr];

		O_wb_ack <= (I_wb_stb & !I_vga_req);
	end

endmodule