module sram512kx8_wb8
	(
		// Wishbone signals
		input CLK_I,
		input STB_I,
		input WE_I,
		input[18:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O,

		// SRAM signals
		input[7:0] I_data,
		output[7:0] O_data,
		output[15:0] O_address,
		output O_ce, O_oe, O_we,

		// tristate control
		output O_output_enable
	);

	reg[18:0] adr_buf;
	reg[7:0] dat_buf;
	
	wire write = (STB_I & WE_I & CLK_I);

	// tristate data line to SRAM
	assign O_output_enable = (write);
	assign O_data = dat_buf;

	// emit buffered address
	assign O_address = adr_buf[18:0];

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_oe = 0;
	assign O_we = !(write);

	always @(posedge CLK_I) begin
		if(STB_I) begin
			adr_buf <= ADR_I;
			dat_buf <= DAT_I;
		end

		ACK_O <= STB_I;
	end

	always @(negedge CLK_I) begin
		DAT_O <= I_data[7:0];
	end

endmodule