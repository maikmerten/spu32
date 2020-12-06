`default_nettype none

// dithering logic from 8 to 4 bits (one single RGB-channel)
module vga_dither_channel_8_to_4(
        input[7:0] I_data,
        input[3:0] I_threshold,
        output[3:0] O_dithered
    );

    wire[3:0] upper = I_data[7:4];
    wire[3:0] lower = I_data[3:0];
    wire[3:0] thres = I_threshold;

    // are the upper 4 bits greater in value than the lower 4 bits?
    wire upper_gt_lower = upper > lower;
    
    // if the upper four bits are greater in value than the lower four bits, then we 
    // need to subtract 1 (i.e., add 0xF) for dithering. Otherwise, dithering will add 1.
    wire[3:0] adjustment = upper_gt_lower ? 4'hF : 4'h1;

    // determine delta = abs(upper - lower)
    wire[3:0] delta = (upper_gt_lower ? upper : lower) - (upper_gt_lower ? lower : upper);
    
    // if the delta >= threshold, then adjust the output value    
    wire adjust = (delta >= thres);

    assign O_dithered = adjust ? (upper + adjustment) : upper;

endmodule

// 24 bit to 12 bit dithering
module vga_dither_24_to_12(
        input I_clk,
        input I_vsync,
        input I_hsync,
        input[23:0] I_rgb24,
        output reg O_vsync,
        output reg O_hsync,
        output reg[11:0] O_rgb12
    );


    reg prev_hsync = 1'b0, prev_vsync = 1'b0;
    reg col = 1'b0, row = 1'b0, frame = 1'b0;

    reg[3:0] threshold;
    always @(*) begin
        case ({frame, row, col})
            // 2x2 dither matrix for even frames
            3'b000: threshold = 4'd15;
            3'b001: threshold = 4'd3;
            3'b010: threshold = 4'd11;
            3'b011: threshold = 4'd7;
            // 2x2 dither matrix for odd frames
            3'b100: threshold = 4'd7;
            3'b101: threshold = 4'd11;
            3'b110: threshold = 4'd3;
            3'b111: threshold = 4'd15;
        endcase
    end

    // instantiate dithering logic per channel (R, G and B)
    wire[3:0] dithered_r, dithered_g, dithered_b;
    vga_dither_channel_8_to_4 dither_channel_r(
        .I_data(I_rgb24[23:16]),
        .I_threshold(threshold),
        .O_dithered(dithered_r)
    );
    vga_dither_channel_8_to_4 dither_channel_g(
        .I_data(I_rgb24[15:8]),
        .I_threshold(threshold),
        .O_dithered(dithered_g)
    );
    vga_dither_channel_8_to_4 dither_channel_b(
        .I_data(I_rgb24[7:0]),
        .I_threshold(threshold),
        .O_dithered(dithered_b)
    );


    always @(posedge I_clk) begin
        // each clock, advance to next column
        col <= !col;

        if(!prev_hsync && I_hsync) begin
            // hsync pulse detected, advance to next row
            row <= !row;
        end

        if(!prev_vsync && I_vsync) begin
            // new frame, toggle odd/even frame, reset row/col
            frame <= !frame;
            row <= 1'b0;
            col <= 1'b0;
        end


        prev_hsync <= I_hsync;
        prev_vsync <= I_vsync;

        O_vsync <= I_vsync;
        O_hsync <= I_hsync;
        O_rgb12 <= {dithered_r, dithered_g, dithered_b};
    end




endmodule