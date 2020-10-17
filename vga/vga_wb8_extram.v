`include "vga/vga.v"

module vga_wb8_extram (
        // Wisbhone B4 signals
        input[12:0] I_wb_adr, // 2^13 addresses
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat,

        // reset signal
        input I_reset,

        // signals to external RAM
        output[17:0] O_ram_adr,
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
    reg[23:0] tmp = 0;

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
                case(I_wb_adr[3:0])
                    // write access to bitmap/text base address
                    4'h0: tmp[7:0] <= I_wb_dat;
                    4'h1: tmp[15:8] <= I_wb_dat;
                    4'h2: tmp[23:16] <= I_wb_dat;
                    4'h3: ram_base <= tmp[18:1];

                    // write access to font base address
                    4'h4: tmp[7:0] <= I_wb_dat;
                    4'h5: tmp[15:8] <= I_wb_dat;
                    4'h6: tmp[23:16] <= I_wb_dat;
                    4'h7: font_base <= tmp[18:1];

                    // write access to update color palette
                    4'h8: palette_update[7:0] <= I_wb_dat; // B component
                    4'h9: palette_update[15:8] <= I_wb_dat; // G component
                    4'hA: palette_update[23:16] <= I_wb_dat; // R component
                    4'hB: begin 
                        palette_update[31:24] <= I_wb_dat; // palette entry index
                        palette_update_request <= !palette_update_ack; // request palette update
                    end

                    // 4'hC current line - read only
                    // 4'hD current line - read only

                    // 4'hE visible line - read only
                    
                    // write access to graphics mode register
                    4'hF: mode <= I_wb_dat[2:0];

                    default: begin end

                endcase
            end else begin
                case(I_wb_adr[3:0])
                    // read access for bitmap/text base address
                    4'h0: O_wb_dat <= {ram_base[6:0], 1'b0};
                    4'h1: O_wb_dat <= ram_base[14:7];
                    4'h2: O_wb_dat <= {5'b00000, ram_base[17:15]};
                    4'h3: O_wb_dat <= 8'b0;

                    // read access for font base address
                    4'h4: O_wb_dat <= {font_base[6:0], 1'b0};
                    4'h5: O_wb_dat <= font_base[14:7];
                    4'h6: O_wb_dat <= {5'b00000, font_base[17:15]};
                    4'h7: O_wb_dat <= 8'b0;

                    // read access to color palette update (quite useless?)
                    4'h8: O_wb_dat <= palette_update[7:0];
                    4'h9: O_wb_dat <= palette_update[15:8];
                    4'hA: O_wb_dat <= palette_update[23:16];
                    4'hB: O_wb_dat <= palette_update[31:24];

                    // read access to current line
                    4'hC: begin
                        O_wb_dat <= vga_row[7:0];
                        tmp[1:0] <= vga_row[9:8];
                    end
                    4'hD: O_wb_dat <= {{6{1'b0}}, tmp[1:0]};

                    // read access to visible line flag
                    4'hE: O_wb_dat <= {{7{1'b0}}, vga_visible};

                    // read access to graphics mode register
                    4'hF: O_wb_dat <= {5'b000000, mode};

                    default: O_wb_dat <= 8'h00;
                endcase
            end
        end

        O_wb_ack <= I_wb_stb;


        if(I_reset) begin
            mode <= MODE_OFF;
        end

    end

endmodule