module vga_wb8_extram (
        // naming according to Wisbhone B4 spec
        input[12:0] ADR_I, // 2^13 addresses
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        output reg ACK_O,
        output reg[7:0] DAT_O,

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
    localparam v_visible = 400;
    localparam v_front_porch = 12;
    localparam v_pulse = 2;
    localparam v_back_porch = 35;


    localparam colhi = $clog2(h_front_porch + h_pulse + h_back_porch + h_visible);
    localparam rowhi = $clog2(v_front_porch + v_pulse + v_back_porch + v_visible);


    reg[colhi:0] col = 0;
    reg[rowhi:0] row = 0;
    
    reg col_is_visible = 0;
    reg row_is_visible = 0;

    reg[18:0] ram_base = 128 * 1024;
    reg[18:0] ram_adr = 0;
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

    reg[5:0] rgbvalue;
    always @(*) begin
        rgbvalue = RGBcolor(col[0] ? ram_dat[7:4] : ram_dat[3:0]);
    end

    always @(posedge I_vga_clk) begin

        if(row_is_visible && col == (h_front_porch + h_pulse + h_back_porch - 3)) begin
            ram_fetch <= 1;
        end
        if(col == (h_front_porch + h_pulse + h_back_porch + h_visible - 3)) begin
            ram_fetch <= 0;
        end

        if(ram_fetch && !col[0]) begin
            O_ram_req <= 1;
            O_ram_adr <= ram_adr;
            ram_adr <= ram_adr + 1;
            ram_dat <= I_ram_dat;
        end else begin
            O_ram_req <= 0;
        end


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
            {O_vga_r1, O_vga_r0, O_vga_g1, O_vga_g0, O_vga_b1, O_vga_b0} <= rgbvalue;
        end else begin
            {O_vga_r1, O_vga_r0, O_vga_g1, O_vga_g0, O_vga_b1, O_vga_b0} <= 6'b000000;
        end




        if(col == h_front_porch + h_pulse + h_back_porch + h_visible - 1) begin
            col <= 0;
            col_is_visible <= 0;

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
    
    always @(posedge CLK_I) begin
        if(STB_I) begin
            if(WE_I) begin
                case(ADR_I[1:0])
                    0: tmp[7:0] <= DAT_I;
                    1: tmp[15:8] <= DAT_I;
                    2: tmp[23:16] <= DAT_I;
                    default: ram_base <= tmp[18:0];
                endcase
            end else begin
                case(ADR_I[1:0])
                    0: DAT_O <= ram_base[7:0];
                    1: DAT_O <= ram_base[15:8];
                    2: DAT_O <= {5'b00000, ram_base[18:16]};
                    default: DAT_O <= 8'b0;
                endcase
            end
        end

        ACK_O <= STB_I;
    end

endmodule