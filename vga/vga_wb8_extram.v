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
        output reg[18:0] O_ram_adr,
        output reg O_ram_req = 0,
        input[7:0] I_ram_dat,

        // VGA signals
        input I_vga_clk,
        output reg O_vga_vsync, O_vga_hsync, O_vga_r0, O_vga_r1, O_vga_g0, O_vga_g1, O_vga_b0, O_vga_b1
    );


    localparam h_visible = 640;
    localparam h_front_porch = 16;
    localparam h_pulse = 96;
    localparam h_back_porch = 48;
    localparam v_visible = 480;
    localparam v_front_porch = 10;
    localparam v_pulse = 2;
    localparam v_back_porch = 33;


    localparam colhi = $clog2(h_front_porch + h_pulse + h_back_porch + h_visible);
    localparam rowhi = $clog2(v_front_porch + v_pulse + v_back_porch + v_visible);


    reg[colhi:0] col = 0;
    reg[rowhi:0] row = 0;
    
    reg col_is_visible = 0;
    reg row_is_visible = 0;

    localparam MODE_TEXT_40 = 0;
    localparam MODE_GRAPHICS_640_640 = 1;

    reg[1:0] mode = MODE_TEXT_40;

    reg[18:0] ram_base = 128 * 1024;
    reg[18:0] ram_adr = 0;

    reg[18:0] font_base = 256 * 1024;
    reg[7:0] char_byte = 0;
    reg[0:7] font_byte = 0, font_byte2 = 0; // reversed bit order for easier lookup according to column
    reg[7:0] color_byte = 0, color_byte2 = 0;

    reg[6:0] text_col = 0;

    reg[7:0] ram_dat;
    reg ram_fetch = 0;

    reg[23:0] tmp;


    // default 16-color EGA palette
    function[5:0] RGBcolor;
        input[3:0] incolor;
        case(incolor)
            0: RGBcolor = 6'b000000;
            1: RGBcolor = 6'b000010;
            2: RGBcolor = 6'b001000;
            3: RGBcolor = 6'b001010;
            4: RGBcolor = 6'b100000;
            5: RGBcolor = 6'b100010;
            6: RGBcolor = 6'b100100;
            7: RGBcolor = 6'b101010;
            8: RGBcolor = 6'b010101;
            9: RGBcolor = 6'b010111;
            10: RGBcolor = 6'b011101;
            11: RGBcolor = 6'b011111;
            12: RGBcolor = 6'b110101;
            13: RGBcolor = 6'b110111;
            14: RGBcolor = 6'b111101;
            15: RGBcolor = 6'b111111;
        endcase
    endfunction

    reg[3:0] coloridx = 0;
    always @(*) begin
        if(col_is_visible && row_is_visible) begin
            if(mode == MODE_TEXT_40) begin
                coloridx = font_byte[col[4:1]] ? color_byte2[7:4] : color_byte2[3:0];
            end else begin
                coloridx = !col[0] ? ram_dat[7:4] : ram_dat[3:0];
            end
        end else begin
            coloridx = 0;
        end
    end


    always @(posedge I_vga_clk) begin

        O_ram_req <= 0;

        if(mode == MODE_GRAPHICS_640) begin
            if(row_is_visible && col == (h_front_porch + h_pulse + h_back_porch - 4)) begin
                ram_fetch <= 1;
            end
            if(col == (h_front_porch + h_pulse + h_back_porch + h_visible - 4)) begin
                ram_fetch <= 0;
            end

            if(ram_fetch && col[0]) begin
                O_ram_req <= 1;
                O_ram_adr <= ram_adr;
                ram_adr <= ram_adr + 1;
            end

            if(col[0]) begin
                ram_dat <= I_ram_dat;
            end

        end else begin
            // 40 column text mode
            if(row_is_visible && col == (h_front_porch + h_pulse + h_back_porch - 15)) begin
                ram_fetch <= 1;
            end
            if(col == (h_front_porch + h_pulse + h_back_porch + h_visible - 15)) begin
                ram_fetch <= 0;
                if(row[3:0] == 15) ram_adr <= ram_adr + 80;
            end

            if(ram_fetch) begin
                if(col[3:0] == 0) begin
                end else if(col[3:0] == 9) begin
                    O_ram_req <= 1;
                    O_ram_adr <= ram_adr + {text_col, 1'b0};
                end else if(col[3:0] == 11) begin
                    char_byte <= I_ram_dat;
                    O_ram_req <= 1;
                    O_ram_adr <= ram_adr + {text_col, 1'b1};
                    text_col <= text_col + 1;
                end else if(col[3:0] == 13) begin
                    color_byte <= I_ram_dat;
                    O_ram_req <= 1;
                    O_ram_adr <= font_base + {char_byte, row[3:1]};
                end else if(col[3:0] == 15) begin
                    font_byte <= I_ram_dat;
                    color_byte2 <= color_byte;
                end
            end
        end


        {O_vga_r1, O_vga_r0, O_vga_g1, O_vga_g0, O_vga_b1, O_vga_b0} <= RGBcolor(coloridx);

        // generate sync signals
        if(col == h_front_porch - 1) begin
            O_vga_hsync <= 0;
        end

        if(col == h_front_porch + h_pulse - 1) begin
            O_vga_hsync <= 1;
        end

        if(col == h_front_porch + h_pulse + h_back_porch - 1) begin
            col_is_visible <= 1;
        end

        if(row == v_visible + v_front_porch - 1) begin
            O_vga_vsync <= 0;
        end

        if(row == v_visible + v_front_porch + v_back_porch - 1) begin
            O_vga_vsync <= 1;
        end


        if(col == h_front_porch + h_pulse + h_back_porch + h_visible - 1) begin
            col <= 0;
            col_is_visible <= 0;
            text_col <= 0;

            if(row == v_visible + v_front_porch + v_pulse + v_back_porch - 1) begin
                // return to first line
                row <= 0;
                row_is_visible <= 1;

                // reset RAM address to start of framebuffer
                ram_adr <= ram_base;
            end else begin
                // progress to next line
                row <= row + 1;
            end

            if(row == v_visible - 1) begin
                row_is_visible <= 0;
            end

        end else begin
            col <= col + 1;
        end


    end
    
    always @(posedge I_wb_clk) begin
        if(I_wb_stb) begin
            if(I_wb_we) begin
                case(I_wb_adr[3:0])
                    0: tmp[7:0] <= I_wb_dat;
                    1: tmp[15:8] <= I_wb_dat;
                    2: tmp[23:16] <= I_wb_dat;
                    3: ram_base <= tmp[18:0];
                    4: tmp[7:0] <= I_wb_dat;
                    5: tmp[15:8] <= I_wb_dat;
                    6: tmp[23:16] <= I_wb_dat;
                    7: font_base <= tmp[18:0];
                    default: mode <= I_wb_dat[1:0];
                    
                endcase
            end else begin
                case(I_wb_adr[3:0])
                    0: O_wb_dat <= ram_base[7:0];
                    1: O_wb_dat <= ram_base[15:8];
                    2: O_wb_dat <= {5'b00000, ram_base[18:16]};
                    3: O_wb_dat <= 8'b0;
                    4: O_wb_dat <= font_base[7:0];
                    5: O_wb_dat <= font_base[15:8];
                    6: O_wb_dat <= {5'b00000, font_base[18:16]};
                    7: O_wb_dat <= 8'b0;
                    default: O_wb_dat <= {6'b000000, mode};
                endcase
            end
        end

        O_wb_ack <= I_wb_stb;


        if(I_reset) begin
            mode <= MODE_TEXT_40;
        end

    end

endmodule