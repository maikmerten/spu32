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
		output reg [7:0] O_data,
		output reg [18:0] O_address,
		output reg O_oe,
		output O_ce, O_we,

		// tristate control
		output reg O_output_enable
	);

	
	wire write = (stb_buf & we_buf & CLK_I);

	reg we_buf = 0;
	reg stb_buf = 0;

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !(write);

	always @(posedge CLK_I) begin
		O_oe <= 1; // active low
		O_output_enable <= 0;
		we_buf <= WE_I;
		stb_buf <= STB_I;

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