module sram64kx16_wb8
	(
		// Wishbone signals
		input CLK_I,
		input STB_I,
		input WE_I,
		input[16:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O,

		// SRAM signals
		inout[15:0] IO_data,
		output[15:0] O_address,
		output O_ce, O_oe, O_we, O_ub, O_lb
	);

	
	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I;
	wire upper_byte = ADR_I[0];
	wire lower_byte = !upper_byte;

	// tristate data line to SRAM
	assign IO_data = write ? {DAT_I, DAT_I} : 16'bz;
	// select requested 8 bits from 16 bit data line
	assign DAT_O = upper_byte ? IO_data[15:8] : IO_data[7:0];

	assign O_address = ADR_I[16:1];

	// control signals are active low, thus negated
	assign O_ce = !(write | read);
	assign O_oe = !read;
	assign O_we = !write;
	assign O_lb = !lower_byte;
	assign O_ub = !upper_byte;

	always @(posedge CLK_I) begin
		ACK_O <= STB_I;
	end

endmodule