`include "vga/vga.v"

module vga_wb32_extram (
        // Wisbhone B4 signals
        input I_wb_clk,
        input[1:0] I_wb_adr,
        input[3:0] I_wb_sel,
        input[31:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[31:0] O_wb_dat,

        // reset signal
        input I_reset,

        // signals to external RAM
        output[17:0] O_ram_adr, // address to 16-bit words
        output O_ram_req,
        input[15:0] I_ram_dat,

        // VGA signals
        input I_vga_clk,
        output O_vga_vsync, O_vga_hsync,
        output[7:0] O_vga_r,
        output[7:0] O_vga_g,
        output[7:0] O_vga_b
    );


    localparam MODE_OFF = 3'b000;
    localparam MODE_TEXT_40 = 3'b001;
    localparam MODE_GRAPHICS_640 = 3'b010;
    localparam MODE_GRAPHICS_320 = 3'b011;
    localparam MODE_TEXT_80 = 3'b100;

    reg[2:0] mode = MODE_TEXT_40;

    // map old modes to new VGA capabilities
    reg[3:0] vga_mode;
    always @(*) begin
        case(mode)
            MODE_TEXT_40: vga_mode = 4'b0111;
            MODE_GRAPHICS_640: vga_mode = 4'b0100;
            MODE_GRAPHICS_320: vga_mode = 4'b0101;
            MODE_TEXT_80: vga_mode = 4'b0110;
            default: vga_mode = 4'b0000;
        endcase
    end


    reg[17:0] ram_base = 128 * 1024;
    reg[17:0] font_base = 256 * 1024;


    reg[31:0] palette_update;
    reg palette_update_request = 0;
    wire palette_update_ack;


    wire[17:0] vga_ram_adr;
    wire vga_ram_req, vga_vsync, vga_hsync;
    wire[23:0] vga_rgb;
    wire[9:0] vga_row;
    wire vga_visible;
    vga vga_inst(
        .I_vga_clk(I_wb_clk),
        .I_mode(vga_mode),
        .I_ram_dat(I_ram_dat),
        .I_base_adr(ram_base),
        .I_font_adr(font_base),
        .I_palette_update_req(palette_update_request),
        .I_palette_update(palette_update),
        .O_palette_update_ack(palette_update_ack),
        .O_ram_adr(vga_ram_adr),
        .O_ram_req(vga_ram_req),
        .O_vsync(vga_vsync),
        .O_hsync(vga_hsync),
        .O_rgb(vga_rgb),
        .O_row(vga_row),
        .O_visible(vga_visible)
    );

    assign O_vga_r = vga_rgb[23:16];
    assign O_vga_g = vga_rgb[15:8];
    assign O_vga_b = vga_rgb[7:0];
    assign O_vga_vsync = vga_vsync;
    assign O_vga_hsync = vga_hsync;

    assign O_ram_req = vga_ram_req;
    assign O_ram_adr = vga_ram_adr;

    
    
    always @(posedge I_wb_clk) begin
        if(I_wb_stb) begin
            if(I_wb_we) begin
                case(I_wb_adr[1:0])
                    // write access to bitmap/text base address
                    2'b00: ram_base <= I_wb_dat[18:1];

                    // write access to font base address
                    2'b01: font_base <= I_wb_dat[18:1];

                    // write access to update color palette
                    2'b10: begin
                        // I_wb_dat[7:0] - B component
                        // I_wb_dat[15:8] - G component
                        // I_wb_dat[23:16] - R component
                        // I_wb_dat[31:24] - palette entry index
                        palette_update <= I_wb_dat;
                        // request palette update
                        palette_update_request <= !palette_update_ack;
                    end

                    2'b11: begin
                        // I_wb_sel[0]: current line LSB - read only
                        // I_wb_sel[1]: current line MSB - read-only
                        // I_wb_sel[2]: line visible flag - read only
                        if(I_wb_sel[3]) begin // graphics mode register
                            mode <= I_wb_dat[26:24];
                        end
                    end

                endcase
            end else begin
                case(I_wb_adr[1:0])
                    // read access for bitmap/text base address
                    2'b00: O_wb_dat <= {13'b0, ram_base[17:0], 1'b0};

                    // read access for font base address
                    2'b01: O_wb_dat <= {13'b0, font_base[17:0], 1'b0};

                    // read access to color palette update (quite useless?)
                    2'b10: O_wb_dat <= palette_update;
                    
                    2'b11: begin
                        // read access to current line
                        O_wb_dat[15:0] <= {{6{1'b0}}, vga_row[9:0]};
                        // read access to line visible flag
                        O_wb_dat[23:16] <= {{7{1'b0}}, vga_visible};
                        // read access to graphics mode register
                        O_wb_dat[31:24] <= {5'b000000, mode};
                    end
                endcase
            end
        end

        O_wb_ack <= I_wb_stb;


        if(I_reset) begin
            mode <= MODE_OFF;
        end

    end

endmodule