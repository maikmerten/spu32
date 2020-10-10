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
		output[15:0] O_vga_dat,

		// SRAM signals
		inout[15:0] IO_data,
		output[17:0] O_address,
		output reg O_lb, O_ub,
		output O_oe, O_ce, O_we,
	);

    localparam DATABITS = 16;
    localparam ADDRBITS = 19;
	
	reg write1 = 0;
	reg write2 = 0;
	wire writepulse = (write1 != write2);

	reg read1 = 0;
	reg read2 = 0;
	wire readpulse = (read1 != read2);

	wire[15:0] writedata = {I_wb_dat, I_wb_dat};

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !writepulse;
	assign O_oe = !readpulse;

	assign O_wb_stall = I_wb_stb & I_vga_req;

	wire[DATABITS-1:0] sram_data;
    wire[ADDRBITS-2:0] sram_addr = I_vga_req ? I_vga_adr[ADDRBITS-1:1] : I_wb_adr[ADDRBITS-1:1];

	genvar i;

    // SB_IO instances for address lines to SRAM chip
    for(i = 0; i < (ADDRBITS - 1); i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(O_address[i]),
            .OUTPUT_CLK(I_wb_clk),
            .D_OUT_0(sram_addr[i]),
        );
    end

    // SB_IO instances for data signals to SRAM chip
    for(i = 0; i < DATABITS; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 1001_00), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(IO_data[i]),
            .OUTPUT_ENABLE(writepulse),
            .INPUT_CLK(I_wb_clk),
            .OUTPUT_CLK(I_wb_clk),
            .D_OUT_0(writedata[i]),
            .D_IN_1(sram_data[i])
        ); 
    end

	reg address_lsb;
	assign O_wb_dat = address_lsb ? sram_data[15:8] : sram_data[7:0];
	assign O_vga_dat = sram_data;


	always @(posedge I_wb_clk) begin

		if(I_vga_req) begin
			read1 <= !read2; // initiate read

			// read upper and lower byte
			O_lb <= 1'b0;
			O_ub <= 1'b0;
		end else if(I_wb_stb) begin
			address_lsb <= I_wb_adr[0];

			O_lb <= I_wb_adr[0];
			O_ub <= !I_wb_adr[0];

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