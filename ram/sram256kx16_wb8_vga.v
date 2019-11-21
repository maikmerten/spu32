module sram256kx16_wb8_vga
	(
		// Wishbone signals
		input I_wb_clk,
		input I_wb_stb,
		input I_wb_we,
		input[18:0] I_wb_adr,
		input[7:0] I_wb_dat,
		output reg [7:0] O_wb_dat,
		output reg O_wb_ack,
		output O_wb_stall,

		// read port for VGA
		input I_vga_req,
		input[18:0] I_vga_adr,

		// SRAM signals
		input[15:0] I_data,
		output reg [15:0] O_data,
		output[17:0] O_address,
		output O_oe, O_ce, O_we, O_lb, O_ub,

		// tristate control
		output reg O_output_enable
	);

	
	reg write1 = 0;
	reg write2 = 0;

	reg output1 = 0;
	reg output2 = 0;

	reg[18:0] address;
	assign O_address = address[18:1];
	assign O_lb = address[0];
	assign O_ub = !address[0];

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !(write1 != write2);
	assign O_oe = !(output1 != output2);

	assign O_wb_stall = I_wb_stb & I_vga_req;

	always @(posedge I_wb_clk) begin
		O_data <= {I_wb_dat, I_wb_dat};
		O_output_enable <= 0;
	
		if(I_vga_req) begin
			address <= I_vga_adr;
			O_output_enable <= 0;
			output1 <= !output2;
		end else if(I_wb_stb) begin
			address <= I_wb_adr;
			if(I_wb_we) begin
				write1 <= !write2;
			end else begin
				output1 <= !output2;
			end
			O_output_enable <= I_wb_we;
		end

		O_wb_ack <= (I_wb_stb & !I_vga_req);
	end

	always @(negedge I_wb_clk) begin
		O_wb_dat <= address[0] ? I_data[15:8] : I_data[7:0];
		write2 <= write1;
		output2 <= output1;
	end

endmodule