module sram256kx16_wb8_vga_ice40
	(
		// Wishbone signals
		input I_wb_clk,
		input I_wb_stb,
		input I_wb_we,
		input[18:0] I_wb_adr,
		input[7:0] I_wb_dat,
		output [7:0] O_wb_dat,
		output reg O_wb_ack,
		output O_wb_stall,

		// read port for VGA
		input I_vga_req,
		input[18:0] I_vga_adr,

		// SRAM signals
		inout[15:0] IO_data,
		output[17:0] O_address,
		output O_oe, O_ce, O_we, O_lb, O_ub,
	);

	
	reg write1 = 0;
	reg write2 = 0;
	wire writepulse = (write1 != write2);

	reg read1 = 0;
	reg read2 = 0;
	wire readpulse = (read1 != read2);

	wire[15:0] writedata = {I_wb_dat, I_wb_dat};

	reg[18:0] address;
	assign O_address = address[18:1];
	assign O_lb = address[0];
	assign O_ub = !address[0];

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !writepulse;
	assign O_oe = !readpulse;

	assign O_wb_stall = I_wb_stb & I_vga_req;

	wire[15:0] sram_data;

	genvar i;
    // SB_IO instances for data signals to SRAM chip
    for(i = 0; i < 16; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 1001_00), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(IO_data[i]),
            .OUTPUT_ENABLE(writepulse),
            .CLOCK_ENABLE(1'b1), // defaults to 1 anyways
            .INPUT_CLK(I_wb_clk),
            .OUTPUT_CLK(I_wb_clk),
            .D_OUT_0(writedata[i]),
            .D_IN_1(sram_data[i])
        ); 
    end

	assign O_wb_dat = address[0] ? sram_data[15:8] : sram_data[7:0];


	always @(posedge I_wb_clk) begin

		if(I_vga_req) begin
			address <= I_vga_adr;
			read1 <= !read2; // initiate read
		end else if(I_wb_stb) begin
			address <= I_wb_adr;
			if(I_wb_we) begin
				write1 <= !write2; // initiate write
			end else begin
				read1 <= !read2; // initiate read
			end
		end

		O_wb_ack <= (I_wb_stb & !I_vga_req);
	end

	always @(negedge I_wb_clk) begin
		write2 <= write1;
		read2 <= read1;
	end

endmodule