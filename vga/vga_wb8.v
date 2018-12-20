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
    localparam h_front_porch = 16;
    localparam h_pulse = 96;
    localparam h_back_porch = 48;
    localparam v_visible = 480;
    localparam v_front_porch = 10;
    localparam v_pulse = 2;
    localparam v_back_porch = 33;

    localparam colhi = $clog2(h_visible + h_front_porch + h_pulse + h_back_porch);
    localparam rowhi = $clog2(v_visible + v_front_porch + v_pulse + v_back_porch);

    localparam text_cols = 40;
    localparam text_rows = 30;


    reg[colhi:0] col = 0;
    reg[rowhi:0] row = 0;

    reg[7:0] ram_font[2047:0];
    reg[7:0] ram_text[2047:0];
    reg[10:0] ram_text_offset = 0;
    reg[10:0] ram_text_addr = 0;

    initial $readmemh("vga/font.dat", ram_font, 0, 2047);
    initial $readmemh("vga/text.dat", ram_text, 0, 2047);

    reg[7:0] font_byte, text_char;

    reg[colhi:0] col_next;
    reg[rowhi:0] row_next;

    reg[5:0] text_col = 0;

    // determine next row and col
    always @(*) begin
        col_next = col + 1;
        row_next = row;

        if(col == (h_visible + h_front_porch + h_pulse + h_back_porch - 1)) begin
            // got to next line
            col_next = 0;
            row_next = row + 1;
        end

        if(row == (v_visible + v_front_porch + v_pulse + v_back_porch - 1)) begin
            row_next = 0;
        end
    end


    // pick bit of font byte corresponding to current column
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

    // compute address into text RAM
    always @(*) begin
        ram_text_addr = ram_text_offset + text_col;
    end


    always @(posedge I_vga_clk) begin
        if(col < h_visible && row < v_visible) begin
            O_vga_r <= fontpixel;
            O_vga_g <= fontpixel;
            O_vga_b <= fontpixel;

            if(col[3:0] == 4'b1101) begin
                // increment early so that the text char and then the font byte can be loaded
                text_col <= text_col + 1;
            end

        end else begin
            // not in visible region
            O_vga_r <= 0;
            O_vga_g <= 0;
            O_vga_b <= 0;

            text_col <= 0;
        end

        // fetch text char
        text_char <= ram_text[ram_text_addr];
        font_byte <= ram_font[{text_char, row[3:1]}];


        if(col == (h_visible + h_front_porch - 1)) begin
            O_vga_hsync <= 0;

            if(row[3:0] == 4'b1111) begin
					// we're in last column of this text row, increment memory offset
					ram_text_offset <= ram_text_offset + text_cols;
            end

        end

        if(col == (h_visible + h_front_porch + h_pulse - 1)) begin
            O_vga_hsync <= 1;
        end


        if((row >= v_visible + v_front_porch) && row < (v_visible + v_front_porch + v_pulse)) begin
            O_vga_vsync <= 0;
        end else begin
            O_vga_vsync <= 1;
        end

        if(row > v_visible) begin
            // reset offset into text RAM during vertical blank
            ram_text_offset <= 0;
        end



        col <= col_next;
        row <= row_next;

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