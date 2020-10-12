`default_nettype none

`include "vga/vga_mode_generator.v"
`include "vga/vga_sync.v"
`include "vga/vga_pixelpipe_test.v"
`include "vga/vga_pixelpipe_text.v"
`include "vga/vga_pixelpipe_bitmap.v"
`include "vga/vga_palette.v"


module vga (
        input I_vga_clk,
        input[3:0] I_mode,
        input[15:0] I_ram_dat,
        input[17:0] I_base_adr,
        input[17:0] I_font_adr,
        output[17:0] O_ram_adr,
        output O_ram_req,
        output O_vsync, O_hsync,
        output[23:0] O_rgb
    );

    wire[15:0] ram_dat;
    reg[17:0] ram_adr;
    reg ram_req;

    assign ram_dat = I_ram_dat;
    assign O_ram_adr = ram_adr;
    assign O_ram_req = ram_req;

    wire timing_select = I_mode[3];
    wire test_mode = I_mode[2:0] == 3'b000;
    wire text_mode = I_mode[1];
    wire doubled_mode = I_mode[0];


    wire[9:0] last_visible_col, h_pulse_start, h_pulse_end, last_col;
    wire[9:0] last_visible_row, v_pulse_start, v_pulse_end, last_row;
    wire v_pulse_polarity, h_pulse_polarity;
    vga_mode_generator vga_mode_generator_inst(
        .I_mode(timing_select),
        .O_last_visible_col(last_visible_col),
        .O_h_pulse_start(h_pulse_start),
        .O_h_pulse_end(h_pulse_end),
        .O_last_col(last_col),
        .O_last_visible_row(last_visible_row),
        .O_v_pulse_start(v_pulse_start),
        .O_v_pulse_end(v_pulse_end),
        .O_last_row(last_row),
        .O_v_pulse_polarity(v_pulse_polarity),
        .O_h_pulse_polarity(h_pulse_polarity)
    );


    wire[9:0] row, col;
    wire vsync, hsync, visible;
    vga_sync vga_sync_inst(
        .I_vga_clk(I_vga_clk),

        .I_last_visible_col(last_visible_col),
        .I_h_pulse_start(h_pulse_start),
        .I_h_pulse_end(h_pulse_end),
        .I_last_col(last_col),

        .I_last_visible_row(last_visible_row),
        .I_v_pulse_start(v_pulse_start),
        .I_v_pulse_end(v_pulse_end),
        .I_last_row(last_row),

        .I_v_pulse_polarity(v_pulse_polarity),
        .I_h_pulse_polarity(h_pulse_polarity),

        .O_row(row),
        .O_col(col),
        .O_vsync(vsync),
        .O_hsync(hsync),
        .O_visible(visible)
    );

    

    wire[7:0] pixelpipe_test_palette_idx;
    wire pixelpipe_test_vsync, pixelpipe_test_hsync, pixelpipe_test_visible;
    vga_pixelpipe_test vga_pixelpipe_test_inst(
        .I_clk(I_vga_clk),
        .I_row(row),
        .I_col(col),
        .I_vsync(vsync),
        .I_hsync(hsync),
        .I_visible(visible),
        .O_palette_idx(pixelpipe_test_palette_idx),
        .O_vsync(pixelpipe_test_vsync),
        .O_hsync(pixelpipe_test_hsync),
        .O_visible(pixelpipe_test_visible)
    );


    wire[7:0] pixelpipe_text_palette_idx;
    wire pixelpipe_text_vsync, pixelpipe_text_hsync, pixelpipe_text_visible, pixelpipe_text_ram_req;
    wire[17:0] pixelpipe_text_ram_adr;
    vga_pixelpipe_text vga_pixelpipe_text_inst(
        .I_clk(I_vga_clk),
        .I_row(row),
        .I_col(col),
        .I_base_adr(I_base_adr),
        .I_font_adr(I_font_adr),
        .I_8x8_font(doubled_mode),
        .I_vsync(vsync),
        .I_hsync(hsync),
        .I_visible(visible),
        .I_ram_dat(ram_dat),
        .O_palette_idx(pixelpipe_text_palette_idx),
        .O_vsync(pixelpipe_text_vsync),
        .O_hsync(pixelpipe_text_hsync),
        .O_visible(pixelpipe_text_visible),
        .O_ram_req(pixelpipe_text_ram_req),
        .O_ram_adr(pixelpipe_text_ram_adr)
    );

    wire[7:0] pixelpipe_bitmap_palette_idx;
    wire pixelpipe_bitmap_vsync, pixelpipe_bitmap_hsync, pixelpipe_bitmap_visible, pixelpipe_bitmap_ram_req;
    wire[17:0] pixelpipe_bitmap_ram_adr;
    vga_pixelpipe_bitmap vga_pixelpipe_bitmap_inst(
        .I_clk(I_vga_clk),
        .I_row(row),
        .I_col(col),
        .I_base_adr(I_base_adr),
        .I_pixel_doubled(doubled_mode),
        .I_vsync(vsync),
        .I_hsync(hsync),
        .I_visible(visible),
        .I_ram_dat(ram_dat),
        .O_palette_idx(pixelpipe_bitmap_palette_idx),
        .O_vsync(pixelpipe_bitmap_vsync),
        .O_hsync(pixelpipe_bitmap_hsync),
        .O_visible(pixelpipe_bitmap_visible),
        .O_ram_req(pixelpipe_bitmap_ram_req),
        .O_ram_adr(pixelpipe_bitmap_ram_adr)
    );


    // select active pixel pipe
    reg[7:0] pixelpipe_palette_idx;
    reg pixelpipe_vsync, pixelpipe_hsync, pixelpipe_visible;
    always @(*) begin
        casez({test_mode, text_mode})
            2'b1?: begin
                // test pipe
                pixelpipe_palette_idx = pixelpipe_test_palette_idx;
                pixelpipe_vsync = pixelpipe_test_vsync;
                pixelpipe_hsync = pixelpipe_test_hsync;
                pixelpipe_visible = pixelpipe_test_visible;
                ram_req = 1'b0;
                ram_adr = 18'b0;
            end

            2'b01: begin
                // text pipe
                pixelpipe_palette_idx = pixelpipe_text_palette_idx;
                pixelpipe_vsync = pixelpipe_text_vsync;
                pixelpipe_hsync = pixelpipe_text_hsync;
                pixelpipe_visible = pixelpipe_text_visible;
                ram_req = pixelpipe_text_ram_req;
                ram_adr = pixelpipe_text_ram_adr;
            end

            2'b00: begin
                // bitmap pipe
                pixelpipe_palette_idx = pixelpipe_bitmap_palette_idx;
                pixelpipe_vsync = pixelpipe_bitmap_vsync;
                pixelpipe_hsync = pixelpipe_bitmap_hsync;
                pixelpipe_visible = pixelpipe_bitmap_visible;
                ram_req = pixelpipe_bitmap_ram_req;
                ram_adr = pixelpipe_bitmap_ram_adr;
            end
        endcase
    end


    wire palette_update_ack;
    wire[23:0] palette_rgb;
    vga_palette vga_palette_inst(
        .I_clk(I_vga_clk),
        .I_update_request(palette_update_ack),
        .I_palette_update(32'h00000000),
        .I_palette_idx(pixelpipe_palette_idx),
        .O_update_ack(palette_update_ack),
        .O_rgb(palette_rgb)
    );


    reg vsync_delay, hsync_delay, visible_delay;
    always @(posedge I_vga_clk) begin
        vsync_delay <= pixelpipe_vsync;
        hsync_delay <= pixelpipe_hsync;
        visible_delay <= pixelpipe_visible;
    end

    assign O_vsync = vsync_delay;
    assign O_hsync = hsync_delay;
    assign O_rgb = visible_delay ? palette_rgb[23:0] : 24'h000000;



   

endmodule