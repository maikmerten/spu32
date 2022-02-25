`default_nettype none

module vga_pixelpipe_bitmap
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

        output reg[7:0] O_palette_idx,
        output reg O_vsync,
        output reg O_hsync,
        output reg O_visible
    );


    // pipeline stage 0
    reg vsync0, hsync0, visible0, fetch0;
    reg[2:0] col0;
    reg[3:0] row0;

    // pipeline stage 1
    reg vsync1, hsync1, visible1, fetch1;
    reg[2:0] col1;
    reg[3:0] row1;

    // pipeline stage 2
    reg[15:0] pixel_data2;

    reg[ADRBITS-1:0] ram_offset = 0;
    reg[ADRBITS-1:0] col_offset = 0;


    wire pixel_doubled;
    assign pixel_doubled = I_pixel_doubled;


    always @(posedge I_clk) begin

        // don't access RAM unless needed
        O_ram_req <= 1'b0;

        // #############################
        // ######### STAGE 0 ###########
        // #############################


        // by default, do not access RAM
        fetch0 <= 1'b0;      
        // fetch pixel data each 4th column
        if(I_col[1:0] == 2'b00) begin
            if(I_visible) begin
                // set up bitmap fetch
                fetch0 <= 1'b1;
                O_ram_req <= 1'b1;
                O_ram_adr <= I_base_adr + ram_offset + col_offset;
            
                // move to next character column
                col_offset <= col_offset + 1;
            end else begin
                // line reached end of visibility
                if(!pixel_doubled || I_row[0] == 1'b1) begin
                    // move RAM offset to next line
                    ram_offset <= ram_offset + col_offset;
                end 

                // reset to column zero
                col_offset <= 0;
            end
        end


        // reset memory offset on invisible lines
        if(I_col == 0 && !I_visible) begin
            ram_offset <= 0;
        end


        {vsync0, hsync0, visible0} <= {I_vsync, I_hsync, I_visible};
        {col0, row0} <= {I_col[2:0], I_row[3:0]};


        // #############################
        // ######### STAGE 1 ###########
        // #############################

        // wait for RAM access
        {vsync1, hsync1, visible1, fetch1} <= {vsync0, hsync0, visible0, fetch0};
        {col1, row1} <= {col0, row0};


        // #############################
        // ######### STAGE 2 ###########
        // #############################

        // RAM data available

        if(fetch1) begin
            // 4 pixels worth of data were fetched. Save data for the other three pixels.
            pixel_data2 <= I_ram_dat;
        end

        if(!pixel_doubled) begin
            // 16-color (4 bit) mode
            case(col1[1:0])
                2'b00: O_palette_idx <= {4'h0, I_ram_dat[15:12]};
                2'b01: O_palette_idx <= {4'h0, pixel_data2[11:8]};
                2'b10: O_palette_idx <= {4'h0, pixel_data2[7:4]};
                2'b11: O_palette_idx <= {4'h0, pixel_data2[3:0]};
            endcase
        end else begin
            // 256-color (8 bit) mode
            case(col1[1:0])
                2'b00: O_palette_idx <= I_ram_dat[15:8];
                2'b01: O_palette_idx <= pixel_data2[15:8];
                2'b10: O_palette_idx <= pixel_data2[7:0];
                2'b11: O_palette_idx <= pixel_data2[7:0];
            endcase
        end


        {O_vsync, O_hsync, O_visible} <= {vsync1, hsync1, visible1};

    end



endmodule