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

		// secondary clock (delayed),
		input I_clk_delayed,

		// SRAM signals
		input[7:0] I_data,
		output[7:0] O_data,
		output[18:0] O_address,
		output O_ce, O_oe, O_we,

		// tristate control
		output O_output_enable
	);

	
	wire write = (STB_I & WE_I & CLK_I);

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !(write);

	always @(posedge CLK_I) begin
		O_oe <= 1; // active low
		O_output_enable <= 0;

		if(STB_I) begin
			O_address <= ADR_I;
			O_data <= DAT_I;
			O_oe <= !(!WE_I); // active low
			O_output_enable <= WE_I;
		end

		ACK_O <= STB_I;
	end

	always @(negedge CLK_I) begin
		DAT_O <= I_data[7:0];
	end

endmodule