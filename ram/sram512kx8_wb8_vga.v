module sram512kx8_wb8_vga
	(
		// Wishbone signals
		input CLK_I,
		input STB_I,
		input WE_I,
		input[18:0] ADR_I,
		input[7:0] DAT_I,
		output reg [7:0] DAT_O,
		output reg ACK_O,
		output STALL_O,

		// read port for VGA
		input VGA_REQ_I,
		input[18:0] VGA_ADR_I,

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
	assign STALL_O = STB_I & VGA_REQ_I;

	always @(posedge CLK_I) begin
		O_oe <= 1; // active low
		O_data <= DAT_I;
		O_output_enable <= 0;
		we_buf <= WE_I;
		stb_buf <= STB_I;
	
		if(VGA_REQ_I) begin
			we_buf <= 0;
			O_address <= VGA_ADR_I;
			O_output_enable <= 0;
			O_oe <= 0;
		end else if(STB_I) begin
			O_address <= ADR_I;
			O_oe <= !(!WE_I); // active low
			O_output_enable <= WE_I;
		end

		ACK_O <= (STB_I & !VGA_REQ_I);
	end

	always @(negedge CLK_I) begin
		DAT_O <= I_data[7:0];
	end

endmodule