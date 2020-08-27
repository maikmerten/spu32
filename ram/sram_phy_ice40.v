`default_nettype none
module sram_phy_ice40
    #(
        parameter ADDRBITS = 18,
        parameter DATABITS = 16
    )
    (
        input I_clk,
        inout[DATABITS-1:0] IO_chip_data,
        output[ADDRBITS-1:0] O_chip_addr,
        output O_chip_ce,
        output O_chip_oe,
        output O_chip_we,
        output O_chip_ub,
        output O_chip_lb,

        input I_stb,
        input I_write,
        input I_ub,
        input I_lb,
        input[ADDRBITS-1:0] I_addr,
        input[DATABITS-1:0] I_data,
        output[DATABITS-1:0] O_data
    );

    reg write1, write2;
    reg read1, read2;

    wire readpulse = (read1 != read2);
    wire writepulse = (write1 != write2);

    always @(posedge I_clk) begin
        if(I_stb) begin
            if(I_write) begin
                write1 <= !write2;
            end else begin
                read1 <= !read2;
            end
        end
    end

    always @(negedge I_clk) begin
        read2 <= read1;
        write2 <= write1;
    end


    wire chip_ce = 1'b0; // active-low
    wire chip_oe = !(readpulse); // active-low
    wire chip_we = !(writepulse); // active-low
    wire chip_ub = !(I_ub); // active-low
    wire chip_lb = !(I_lb); // active-low


    genvar i;

    // SB_IO instances for data signals to SRAM chip
    for(i = 0; i < DATABITS; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 1001_00), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(IO_chip_data[i]),
            .OUTPUT_ENABLE(writepulse),
            //.CLOCK_ENABLE(1'b1), // defaults to 1 anyways
            .INPUT_CLK(I_clk),
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(I_data[i]),
            .D_IN_1(O_data[i])
        ); 
    end

    // SB_IO instances for address lines to SRAM chip
    for(i = 0; i < ADDRBITS; i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(O_chip_addr[i]),
            //.CLOCK_ENABLE(1'b1), // defaults to 1 anyways
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(I_addr[i]),
        );
    end



    wire[2:0] ctrl_out = {O_chip_ce, O_chip_ub, O_chip_lb};
    wire[2:0] ctrl_in = {chip_ce, chip_ub, chip_lb};
    // SB_IO instances for control signals to SRAM chip
    for(i = 0; i < $size(ctrl_out); i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 0101_01), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(ctrl_out[i]),
            //.CLOCK_ENABLE(1'b1), // defaults to 1 anyways
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(ctrl_in[i]),
        );
    end

    // SB_IO for non-registered outputs
    wire[1:0] nonreg_out = {O_chip_oe, O_chip_we};
    wire[1:0] nonreg_in = {chip_oe, chip_we};
    for(i = 0; i < $size(nonreg_out); i = i + 1) begin
        SB_IO #(.PIN_TYPE(6'b 0110_01), .PULLUP(1'b 0)) io_block_instance (
            .PACKAGE_PIN(nonreg_out[i]),
            //.CLOCK_ENABLE(1'b1), // defaults to 1 anyways
            .OUTPUT_CLK(I_clk),
            .D_OUT_0(nonreg_in[i]),
        );
    end



endmodule