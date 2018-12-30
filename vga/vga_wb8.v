module vga_wb8 (
        // naming according to Wisbhone B4 spec
        input[12:0] ADR_I, // 2^13 addresses
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        output reg ACK_O,
        output reg[7:0] DAT_O,

        // VGA signals
        input I_vga_clk,
        output reg O_vga_vsync, O_vga_hsync, O_vga_r, O_vga_g, O_vga_b
    );


    localparam h_visible = 640;
    localparam h_front_porch = 32;
    localparam h_pulse = 96;
    localparam h_back_porch = 32;
    localparam v_visible = 400;
    localparam v_front_porch = 8;
    localparam v_pulse = 8;
    localparam v_back_porch = 64;


    localparam colhi = $clog2(h_front_porch + h_pulse + h_back_porch + h_visible);
    localparam rowhi = $clog2(v_front_porch + v_pulse + v_back_porch + v_visible);

    localparam text_cols = 40;
    localparam text_rows = 25;


    reg[colhi:0] col = 0;
    reg[rowhi:0] row = 0;

    reg[7:0] ram_font[2047:0];
    reg[7:0] ram_text[1023:0];
    reg[10:0] ram_text_offset = 0;
    reg[10:0] ram_text_addr = 0;

    initial $readmemh("vga/font.dat", ram_font, 0, 2047);
    initial $readmemh("vga/text.dat", ram_text, 0, 1023);

    reg[7:0] font_byte, text_char;

    reg col_is_visible = 0;
    reg row_is_visible = 0;

    reg[$clog2(text_cols):0] text_col = 0;

    reg fontpixel;
    always @(*) begin
        case(col[3:1])
            0: fontpixel = font_byte[7];
            1: fontpixel = font_byte[6];
            2: fontpixel = font_byte[5];
            3: fontpixel = font_byte[4];
            4: fontpixel = font_byte[3];
            5: fontpixel = font_byte[2];
            6: fontpixel = font_byte[1];
            7: fontpixel = font_byte[0];
        endcase
    end


    always @(posedge I_vga_clk) begin

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


        if(col_is_visible && row_is_visible) begin
            O_vga_r <= fontpixel;
            O_vga_g <= fontpixel;
            O_vga_b <= fontpixel;
        end else begin
            {O_vga_r, O_vga_g, O_vga_b} <= 3'b000;
        end

        if(col_is_visible && col[3:0] == 4'b1101) begin
            text_col <= text_col + 1;
        end


        text_char <= ram_text[ram_text_offset + text_col];
        font_byte <= ram_font[{text_char, row[3:1]}];


        // increment ram offset on new lines
        if(col == 0 && row[3:0] == 4'b0000) begin
            if(row == 0) begin
                // reset offset on very first line
                ram_text_offset <= 0;
            end else begin
                // otherwise increment by number of bytes per column
                ram_text_offset <= ram_text_offset + text_cols;
            end
        end


        if(col == h_front_porch + h_pulse + h_back_porch + h_visible - 1) begin
            col <= 0;
            col_is_visible <= 0;
            text_col <= 0;

            if(row == v_visible + v_front_porch + v_pulse + v_back_porch - 1) begin
                // return to first line
                row <= 0;
                row_is_visible <= 1;
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
    
    always @(posedge CLK_I) begin
        if(STB_I) begin
            if(WE_I) begin
                casez(ADR_I)

                    //13'b01??????????? color RAM

                    13'b10???????????: begin
                        // font RAM
                        ram_font[ADR_I[10:0]] <= DAT_I;
                    end

                    default: begin
                        ram_text[ADR_I[10:0]] <= DAT_I;
                    end

                endcase
            end
        end

        // ICE40 BRAM is not dual ported, so for now don't allow read access
        DAT_O <= 8'h00;
        ACK_O <= STB_I;
    end

endmodule