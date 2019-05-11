module sram512kx8_wb8_vga
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
		input[7:0] I_data,
		output reg [7:0] O_data,
		output reg [18:0] O_address,
		output reg O_oe,
		output O_ce, O_we,

		// tristate control
		output reg O_output_enable
	);

	
	reg write1 = 0;
	reg write2 = 0;

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !(write1 != write2);
	assign O_wb_stall = I_wb_stb & I_vga_req;

	always @(posedge I_wb_clk) begin
		O_oe <= 1; // active low
		O_data <= I_wb_dat;
		O_output_enable <= 0;
	
		if(I_vga_req) begin
			O_address <= I_vga_adr;
			O_output_enable <= 0;
			O_oe <= 0;
		end else if(I_wb_stb) begin
			write1 <= I_wb_we ? !write2 : write2;
			O_address <= I_wb_adr;
			O_oe <= !(!I_wb_we); // active low
			O_output_enable <= I_wb_we;
		end

		O_wb_ack <= (I_wb_stb & !I_vga_req);
	end

	always @(negedge I_wb_clk) begin
		O_wb_dat <= I_data[7:0];
		write2 <= write1;
	end

endmodule