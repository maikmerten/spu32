`default_nettype none

module vga_pixelpipe_text
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
        input[ADRBITS-1:0] I_font_adr,
        input I_8x8_font,
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
    reg vsync2, hsync2, visible2, fetch2;
    reg[2:0] col2;
    reg[3:0] row2;
    reg[7:0] char2, attributes2;

    // pipeline stage 3
    reg vsync3, hsync3, visible3, fetch3;
    reg[2:0] col3;
    reg[3:0] row3;

    // pipeline stage 4
    reg vsync4, hsync4, visible4, fetch4;
    reg[2:0] col4;
    reg[3:0] row4;

    // pipeline stage 5
    reg vsync5, hsync5, visible5, fetch5;
    reg[2:0] col5;
    reg[3:0] row5;
    reg[7:0] attributes5;
    // reversed bit-direction for font row so that column directly
    // indexes into the bit array
    reg[0:7] font_row5;


    reg[ADRBITS-1:0] ram_offset = 0;
    reg[ADRBITS-1:0] col_offset = 0;

    wire[7:0] ram_dat_char, ram_dat_attributes, ram_dat_font_row_even, ram_dat_font_row_odd;
    assign ram_dat_char = I_ram_dat[15:8];
    assign ram_dat_attributes = I_ram_dat[7:0];
    assign ram_dat_font_row_even = I_ram_dat[15:8];
    assign ram_dat_font_row_odd = I_ram_dat[7:0];

    // for 8x8 fonts, font rows are doubled
    wire font_row_odd = I_8x8_font ? row4[1] : row4[0];

    // for 8x8 fonts, pixels are doubled: New char cols every 16 pixels, not every 8 pixels
    wire new_char_col = I_8x8_font ? I_col[3:0] == 4'b0000 : I_col[2:0] == 3'b000;


    always @(posedge I_clk) begin

        // don't access RAM unless needed
        O_ram_req <= 1'b0;

        // #############################
        // ######### STAGE 0 ###########
        // #############################


        // by default, do not access RAM
        fetch0 <= 1'b0;      
        // start of new character each 8th column
        if(new_char_col) begin
            if(I_visible) begin
                // set up character fetch
                fetch0 <= 1'b1;
                O_ram_req <= 1'b1;
                O_ram_adr <= I_base_adr + ram_offset + col_offset;
            
                // move to next character column
                col_offset <= col_offset + 1;
            end else begin
                // line reached end of visibility
                if(I_row[3:0] == 4'b1111) begin
                    // after 16 lines, increase memory offset by line width
                    ram_offset <= ram_offset + col_offset;
                end 

                // reset to character column zero
                col_offset <= 0;
            end
        end


        // reset memory offset on invisible lines
        if(I_col == 0 && !I_visible) begin
            ram_offset <= 0;
        end


        {vsync0, hsync0, visible0} <= {I_vsync, I_hsync, I_visible};
        // in 8x8 mode, wrap around col every 16 pixel, not every 8 pixel
        {col0, row0} <= {(I_8x8_font ? I_col[3:1] : I_col[2:0]), I_row[3:0]};


        // #############################
        // ######### STAGE 1 ###########
        // #############################

        // wait for (char code + attributes) RAM access
        {vsync1, hsync1, visible1, fetch1} <= {vsync0, hsync0, visible0, fetch0};
        {col1, row1} <= {col0, row0};


        // #############################
        // ######### STAGE 2 ###########
        // #############################

        // (char code + attributes) available

        if(fetch1) begin
            // update char and attribute
            char2 <= ram_dat_char;
            attributes2 <= ram_dat_attributes;
        end


        {vsync2, hsync2, visible2, fetch2} <= {vsync1, hsync1, visible1, fetch1};
        {col2, row2} <= {col1, row1};


        // #############################
        // ######### STAGE 3 ###########
        // #############################

        if(fetch2) begin
            // set up font read
            O_ram_req <= 1'b1;
            O_ram_adr <= I_8x8_font ? I_font_adr + {{(ADRBITS-10){1'b0}}, char2, row2[3:2]} : I_font_adr + {{(ADRBITS-11){1'b0}}, char2, row2[3:1]};
        end

        {vsync3, hsync3, visible3, fetch3} <= {vsync2, hsync2, visible2, fetch2};
        {col3, row3} <= {col2, row2};


        // #############################        
        // ######### STAGE 4 ###########
        // #############################

        // wait for font RAM access
        {vsync4, hsync4, visible4, fetch4} <= {vsync3, hsync3, visible3, fetch3};
        {col4, row4} <= {col3, row3};


        // #############################
        // ######### STAGE 5 ###########
        // #############################

        if(fetch4) begin
            // update font-row byte
            font_row5 <= font_row_odd ? ram_dat_font_row_odd : ram_dat_font_row_even;
            // update attributes
            attributes5 <= attributes2;
        end

        {vsync5, hsync5, visible5, fetch5} <= {vsync4, hsync4, visible4, fetch4};
        {col5, row5} <= {col4, row4};


        // #############################
        // ######### STAGE 6 ###########
        // #############################

        // font data is available
        // determine final pixel value
       
        O_palette_idx <= font_row5[col5] ? {4'h0, attributes5[7:4]} : {4'h0, attributes5[3:0]};
        {O_vsync, O_hsync, O_visible} <= {vsync5, hsync5, visible5};

    end

endmodule