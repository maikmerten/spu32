`default_nettype none


// Interpolate between two 8-bit color channels
module vga_color_interpolator_channel(
        input[7:0] I_channel0,
        input[7:0] I_channel1,
        input I_mode,
        output[7:0] O_interpolated_channel
    );

    reg[7:0] c0_contrib0, c0_contrib1, c1_contrib0, c1_contrib1;

    // scale input value according to selected mode
    always @(*) begin
        case(I_mode)
            1'b0: begin
                c0_contrib0 = {3'b000, I_channel0[7:3]}; // 1/8 c0
                c0_contrib1 = {1'b0,   I_channel0[7:1]}; // 1/2 c0
                c1_contrib0 = {3'b000, I_channel1[7:3]}; // 1/8 c1
                c1_contrib1 = {2'b00,  I_channel1[7:2]}; // 1/4 c1
            end

            1'b1: begin
                c0_contrib0 = {1'b0,   I_channel0[7:1]}; // 1/2 c0
                c0_contrib1 = {2'b00,  I_channel0[7:2]}; // 1/4 c0
                c1_contrib0 = {2'b00,  I_channel1[7:2]}; // 1/4 c1
                c1_contrib1 = 8'h00;
            end
        endcase
    end

    // sum up contributions
    assign O_interpolated_channel = (c0_contrib0 + c0_contrib1) + (c1_contrib0 + c1_contrib1);
endmodule


// Interpolate between two 24-bit RGB values
module vga_color_interpolator_rgb(
        input[23:0] I_rgb0,
        input[23:0] I_rgb1,
        input I_mode,
        output[23:0] O_interpolated_rgb
    );

    wire[7:0] r0 = I_rgb0[23:16];
    wire[7:0] g0 = I_rgb0[15:8];
    wire[7:0] b0 = I_rgb0[7:0];

    wire[7:0] r1 = I_rgb1[23:16];
    wire[7:0] g1 = I_rgb1[15:8];
    wire[7:0] b1 = I_rgb1[7:0];

    wire[7:0] r_interpolated, g_interpolated, b_interpolated;

    // instantiate channel-interpolators for red, green and blue
    vga_color_interpolator_channel channel_inst_r(
        .I_channel0(r0),
        .I_channel1(r1),
        .I_mode(I_mode),
        .O_interpolated_channel(r_interpolated)
    );

    vga_color_interpolator_channel channel_inst_g(
        .I_channel0(g0),
        .I_channel1(g1),
        .I_mode(I_mode),
        .O_interpolated_channel(g_interpolated)
    );

    vga_color_interpolator_channel channel_inst_b(
        .I_channel0(b0),
        .I_channel1(b1),
        .I_mode(I_mode),
        .O_interpolated_channel(b_interpolated)
    );

    // assemble interpolated RGB
    assign O_interpolated_rgb = {r_interpolated, g_interpolated, b_interpolated};
endmodule


// generate four RGB888 colors out of two RGB332 reference colors
module vga_color_interpolator(
        input[7:0] I_reference_color0, // RGB332
        input[7:0] I_reference_color1, // RGB332
        output[23:0] O_color0,
        output[23:0] O_color1,
        output[23:0] O_color2,
        output[23:0] O_color3
    );

    wire mode = I_reference_color0 > I_reference_color1;

    // extract color channels from RGB332
    wire[2:0] r0 = I_reference_color0[7:5];
    wire[2:0] g0 = I_reference_color0[4:2];
    wire[1:0] b0 = I_reference_color0[1:0];

    wire[2:0] r1 = I_reference_color1[7:5];
    wire[2:0] g1 = I_reference_color1[4:2];
    wire[1:0] b1 = I_reference_color1[1:0];

    // assemble RGB332-components to RGB888
    wire[7:0] red8_0 = {r0, r0[1:0], r0[1:0], r0[1]};
    wire[7:0] grn8_0 = {g0, g0[1:0], g0[1:0], g0[1]};
    wire[7:0] blu8_0 = {b0, b0, b0, b0};

    wire[7:0] red8_1 = {r1, r1[1:0], r1[1:0], r1[1]};
    wire[7:0] grn8_1 = {g1, g1[1:0], g1[1:0], g1[1]};
    wire[7:0] blu8_1 = {b1, b1, b1, b1};

    wire[23:0] color0 = {red8_0, grn8_0, blu8_0};
    wire[23:0] color3 = {red8_1, grn8_1, blu8_1};

    wire[23:0] color1, color2;

    vga_color_interpolator_rgb interpolator_rgb_inst_color1(
        .I_rgb0(color0),
        .I_rgb1(color3),
        .I_mode(mode),
        .O_interpolated_rgb(color1)
    );

    vga_color_interpolator_rgb interpolator_rgb_inst_color2(
        .I_rgb0(color3),
        .I_rgb1(color0),
        .I_mode(mode),
        .O_interpolated_rgb(color2)
    );

    assign O_color0 = color0;
    assign O_color1 = color1;
    assign O_color2 = color2;
    assign O_color3 = color3;

endmodule


module vga_pixelpipe_compressed_bitmap
    #(
        parameter COLBITS = 10,
        parameter ROWBITS = 10,
        parameter ADRBITS = 18
    )
    (
        input I_clk,
        input[COLBITS-1:0] I_col,
        input[ROWBITS-1:0] I_row,
        input[ADRBITS-1:0] I_base_adr,
        input I_pixel_doubled,
        input I_vsync,
        input I_hsync,
        input I_visible,
        input[15:0] I_ram_dat,

        output reg O_ram_req,
        output reg[ADRBITS-1:0] O_ram_adr,

        output reg[23:0] O_rgb,
        output reg O_vsync,
        output reg O_hsync,
        output reg O_visible
    );



    // pipeline stage 0
    reg vsync0, hsync0, visible0, fetch0;
    reg[2:0] col0;
    reg[3:0] row0;
    reg[ADRBITS-1:0] block_adr0;

    // pipeline stage 1
    reg vsync1, hsync1, visible1, fetch1;
    reg[2:0] col1;
    reg[3:0] row1;
    reg[ADRBITS-1:0] block_adr1;

    // pipeline stage 2
    reg[15:0] color_data2;
    reg vsync2, hsync2, visible2, fetch2;
    reg[2:0] col2;

    // pipeline stage 3
    reg[15:0] color_data3;
    reg vsync3, hsync3, visible3, fetch3;
    reg[2:0] col3;

    // pipeline stage 4
    reg[13:0] pixel_data4;
    reg[1:0] pixel_idx4;
    always @(*) begin
        case(col3[2:0])
            3'b000: pixel_idx4 = I_ram_dat[15:14]; // just fetched
            3'b001: pixel_idx4 = pixel_data4[13:12];
            3'b010: pixel_idx4 = pixel_data4[11:10];
            3'b011: pixel_idx4 = pixel_data4[9:8];
            3'b100: pixel_idx4 = pixel_data4[7:6];
            3'b101: pixel_idx4 = pixel_data4[5:4];
            3'b110: pixel_idx4 = pixel_data4[3:2];
            3'b111: pixel_idx4 = pixel_data4[1:0];
        endcase
    end


    // instantiate color interpolator to generate four 24-bit colors
    // from two RGB332 colors.
    wire[23:0] color0, color1, color2, color3;
    vga_color_interpolator color_interpolator_inst(
        .I_reference_color0(color_data3[15:8]), // RGB332
        .I_reference_color1(color_data3[7:0]), // RGB332
        .O_color0(color0),
        .O_color1(color1),
        .O_color2(color2),
        .O_color3(color3)
    );
    

    reg[ADRBITS-1:0] ram_base = 0;
    reg[ADRBITS-1:0] block_offset = 0;

    wire[ADRBITS-1:0] block_base_address = ram_base + block_offset;
    
    always @(posedge I_clk) begin

        // don't access RAM unless needed
        O_ram_req <= 1'b0;

        // #############################
        // ######### STAGE 0 ###########
        // #############################


        // by default, do not access RAM
        fetch0 <= 1'b0;      
        // start of new block each 8th column
        if(I_col[2:0] == 3'b000) begin
            if(I_visible) begin
                // set up bitmap fetch
                fetch0 <= 1'b1;
                O_ram_req <= 1'b1;
                O_ram_adr <= block_base_address;
                block_adr0 <= block_base_address;
            
                // move to next block column. Each block is 9 words in size (18 bytes).
                block_offset <= block_offset + 9;
            end else begin
                // line reached end of visibility
                if(I_row[2:0] == 3'b111) begin
                    // every 8 pixel rows, move RAM offset to next row of blocks
                    ram_base <= ram_base + block_offset;
                end 

                // reset to block column zero
                block_offset <= 0;
            end
        end


        // reset memory base on invisible lines
        if(I_col == 0 && !I_visible) begin
            ram_base <= I_base_adr;
        end


        {vsync0, hsync0, visible0} <= {I_vsync, I_hsync, I_visible};
        {col0, row0} <= {I_col[2:0], I_row[3:0]};

        // #############################
        // ######### STAGE 1 ###########
        // #############################

        // wait for RAM access
        {vsync1, hsync1, visible1, fetch1} <= {vsync0, hsync0, visible0, fetch0};
        {col1, row1} <= {col0, row0};
        block_adr1 <= block_adr0;

        // #############################
        // ######### STAGE 2 ###########
        // #############################

        // RAM data available

        if(fetch1) begin
            // save color information for current lbock
            color_data2 <= I_ram_dat;
        end

        fetch2 <= 0;
        if(col1[2:0] == 0) begin
            // need to fetch block pixel data every 8 pixels
            fetch2 <= 1;
            O_ram_req <= 1;
            O_ram_adr <= (block_adr1 + 1) + row1[2:0];
        end


        {vsync2, hsync2, visible2} <= {vsync1, hsync1, visible1};
        col2 <= col1;

        // #############################
        // ######### STAGE 3 ###########
        // #############################

        // wait for RAM access
        {vsync3, hsync3, visible3, fetch3} <= {vsync2, hsync2, visible2, fetch2};
        col3 <= col2;
        color_data3 <= color_data2;

        // #############################
        // ######### STAGE 4 ###########
        // #############################

        if(fetch3) begin
            pixel_data4 <= I_ram_dat[13:0];
        end

        // select from interpolated colors
        case(pixel_idx4)
            2'b00: O_rgb <= color0;
            2'b01: O_rgb <= color1;
            2'b10: O_rgb <= color2;
            2'b11: O_rgb <= color3;
        endcase

        {O_vsync, O_hsync, O_visible} <= {vsync3, hsync3, visible3};


    end



endmodule