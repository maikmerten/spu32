`default_nettype none

module sram256kx16_membus_vga_ice40
	(
		input I_clk,
        input I_clk_90deg,
		// signals to memory bus adapter
        input[3:0] I_request,
        input I_we,
        input I_ub,
        input I_lb,
        input[17:0] I_addr,
        input[15:0] I_data,
        output[15:0] O_data,
        output[3:0] O_ack,
        output O_stall,

		// read port for VGA
		// addresses 16-bit words
		input I_vga_req,
		input[17:0] I_vga_adr,
		output[15:0] O_vga_dat,

		// SRAM signals
		inout[15:0] IO_data,
		output[17:0] O_address,
		output O_lb, O_ub,
		output O_oe, O_ce, O_we
	);

    localparam DATABITS = 16;
    localparam ADDRBITS = 18;

	reg[3:0] ack = 4'h0;
    assign O_ack = ack;

	wire en = (I_request != 4'h0);

	reg stall;
	assign O_stall = stall;

	reg write1 = 0;
	reg write2 = 0;
	wire writepulse = (write1 != write2);

	wire[15:0] writedata = I_data;

	wire[DATABITS-1:0] sram_data;
    wire[ADDRBITS-1:0] sram_addr = I_vga_req ? I_vga_adr : I_addr;

	// control signals are active low, thus negated
	assign O_ce = 0;
	wire ub = I_vga_req ? 1'b0 : !(en & I_ub);
	wire lb = I_vga_req ? 1'b0 : !(en & I_lb);
	wire we = I_vga_req ? 1'b1 : !(en & I_we);
	wire oe = I_vga_req ? 1'b0 : !(en & !I_we);

	// upper-byte control line
	SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance_ub (
		.PACKAGE_PIN(O_ub),
		.OUTPUT_CLK(I_clk),
		.D_OUT_0(ub),
	);

	// lower-byte control line
	SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance_lb (
		.PACKAGE_PIN(O_lb),
		.OUTPUT_CLK(I_clk),
		.D_OUT_0(lb),
	);

	// write control line (DDR output)
	SB_IO #(.PIN_TYPE(6'b 0100_01), .PULLUP(1'b 0)) io_block_instance_we (
		.PACKAGE_PIN(O_we),
		.OUTPUT_CLK(I_clk),
		.D_OUT_0(we),
		.D_OUT_1(1'b1) // disable after negative clock edge
	);

	// output-enable control line (DDR output)
	SB_IO #(.PIN_TYPE(6'b 0100_01), .PULLUP(1'b 0)) io_block_instance_oe (
		.PACKAGE_PIN(O_oe),
		.OUTPUT_CLK(I_clk),
		.D_OUT_0(oe),
		.D_OUT_1(1'b1) // disable after negative clock edge
	);

	genvar i;

    // SB_IO instances for address lines to SRAM chip
    for(i = 0; i < ADDRBITS; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(O_address[i]),
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(sram_addr[i]),
        );
    end

    // SB_IO instances for data signals to SRAM chip
    for(i = 0; i < DATABITS; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 1001_00), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(IO_data[i]),
            .OUTPUT_ENABLE(writepulse),
            .INPUT_CLK(I_clk),
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(writedata[i]),
            .D_IN_1(sram_data[i])
        ); 
    end

	assign O_data = sram_data;
	assign O_vga_dat = {sram_data[7:0], sram_data[15:8]};


	always @(posedge I_clk) begin

        // set up writes
        if(en && !I_vga_req && I_we) begin
            write1 <= !write2;
        end

		ack <= I_request;
		stall <= I_vga_req;
	end

	always @(negedge I_clk) begin
		write2 <= write1;
	end

endmodule