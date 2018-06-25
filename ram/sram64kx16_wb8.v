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

	reg[16:0] adr_buf;
	reg[7:0] dat_buf;
	
	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I; // TODO: removing this line alters timing and leads to read/write fails...
	wire upper_byte = adr_buf[0];
	wire lower_byte = !upper_byte;

	// tristate data line to SRAM
	assign IO_data = write ? {dat_buf, dat_buf} : 16'bz;

	// emit buffered address
	assign O_address = adr_buf[16:1];

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_oe = 0;
	assign O_we = !(write & CLK_I);
	assign O_lb = !(lower_byte & CLK_I);
	assign O_ub = !(upper_byte & CLK_I);

	always @(posedge CLK_I) begin
		if(STB_I) begin
			adr_buf <= ADR_I;
			dat_buf <= DAT_I;
		end

		ACK_O <= STB_I;
	end

	always @(negedge CLK_I) begin
		DAT_O <= lower_byte ? IO_data[15:8] : IO_data[7:0];
	end

endmodule