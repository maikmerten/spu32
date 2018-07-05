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
		input[15:0] I_data,
		output[15:0] O_data,
		output[15:0] O_address,
		output O_ce, O_oe, O_we, O_ub, O_lb,

		// tristate control
		output O_output_enable
	);

	reg[16:0] adr_buf;
	reg[7:0] dat_buf;
	
	wire write = STB_I & WE_I;
	wire read = STB_I & !WE_I;
	wire upper_byte = adr_buf[0];
	wire lower_byte = !adr_buf[0];

	// tristate data line to SRAM
	assign O_output_enable = (write & CLK_I);
	assign O_data = {dat_buf, dat_buf};

	// emit buffered address
	assign O_address = adr_buf[16:1];

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_oe = 0;
	assign O_we = !(write & CLK_I);

	assign O_lb = !((lower_byte & CLK_I & STB_I) | read);
	assign O_ub = !((upper_byte & CLK_I & STB_I) | read);

	always @(posedge CLK_I) begin
		if(STB_I) begin
			adr_buf <= ADR_I;
			dat_buf <= DAT_I;
		end

		ACK_O <= STB_I;
	end

	always @(negedge CLK_I) begin
		DAT_O <= upper_byte ? I_data[15:8] : I_data[7:0];
	end

endmodule