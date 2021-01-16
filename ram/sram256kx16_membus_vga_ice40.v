`default_nettype none

module sram256kx16_membus_vga_ice40
	(
		input I_clk,
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
		output reg O_lb, O_ub,
		output O_oe, O_ce, O_we
	);

    localparam DATABITS = 16;
    localparam ADDRBITS = 19;

	reg[3:0] ack = 4'h0;
    assign O_ack = ack;

	wire en = (I_request != 4'h0);

	reg stall;
	assign O_stall = stall;


	reg write1 = 0;
	reg write2 = 0;
	wire writepulse = (write1 != write2);

	reg read1 = 0;
	reg read2 = 0;
	wire readpulse = (read1 != read2);

	wire[15:0] writedata = I_data;

	// control signals are active low, thus negated
	assign O_ce = 0;
	assign O_we = !writepulse;
	assign O_oe = !readpulse;


	wire[DATABITS-1:0] sram_data;
    wire[ADDRBITS-2:0] sram_addr = I_vga_req ? I_vga_adr : I_addr;

	genvar i;

    // SB_IO instances for address lines to SRAM chip
    for(i = 0; i < (ADDRBITS - 1); i = i + 1) begin
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

		if(I_vga_req) begin
			read1 <= !read2; // initiate read

			// read upper and lower byte
			O_lb <= 1'b0;
			O_ub <= 1'b0;
		end else if(en) begin
			O_lb <= !I_lb; // active low
			O_ub <= !I_ub; // active low

			if(I_we) begin
				write1 <= !write2; // initiate write
			end else begin
				read1 <= !read2; // initiate read
			end
		end

		ack <= I_request;
		stall <= I_vga_req;
	end

	always @(negedge I_clk) begin
		write2 <= write1;
		read2 <= read1;
	end

endmodule