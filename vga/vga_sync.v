`default_nettype none

module vga_sync
    #(
        parameter COLBITS = 10,
        parameter ROWBITS = 10
    )
    (
        input I_vga_clk,
        input[COLBITS-1:0] I_last_visible_col,
        input[COLBITS-1:0] I_h_pulse_start,
        input[COLBITS-1:0] I_h_pulse_end,
        input[COLBITS-1:0] I_last_col,

        input[ROWBITS-1:0] I_last_visible_row,
        input[ROWBITS-1:0] I_v_pulse_start,
        input[ROWBITS-1:0] I_v_pulse_end,
        input[ROWBITS-1:0] I_last_row,

        input I_v_pulse_polarity,
        input I_h_pulse_polarity,

        output[COLBITS-1:0] O_col,
        output[ROWBITS-1:0] O_row,
        output O_hsync, O_vsync, O_visible
    );



    reg hsync;
    assign O_hsync = hsync;

    reg vsync;
    assign O_vsync = vsync;

    reg[COLBITS-1:0] col;
    assign O_col = col;
    wire[COLBITS-1:0] next_col;
    assign next_col = col + 1;



    reg[ROWBITS-1:0] row = 0;
    assign O_row = row;
    wire[ROWBITS-1:0] next_row;
    assign next_row = row + 1;

    reg col_is_visible;
    reg row_is_visible;
    wire visible = col_is_visible & row_is_visible;
    assign O_visible = visible;


    always @(posedge I_vga_clk) begin
        col <= next_col;

        // reached end of visible area in row
        if(col == I_last_visible_col) begin
            col_is_visible <= 1'b0;
        end

        if(col == I_h_pulse_start) begin
            hsync <= I_h_pulse_polarity; //1'b1;
        end

        if(col == I_h_pulse_end) begin
            hsync <= !I_h_pulse_polarity; //1'b0;
        end


        // end of current row reached
        if(col == I_last_col) begin
            // return to first column
            col <= 0;
            col_is_visible <= 1'b1;

            // advance to next row
            row <= next_row;
            if(row == I_last_visible_row) begin
                row_is_visible <= 1'b0;
            end

            if(row == I_v_pulse_start) begin
                vsync <= I_v_pulse_polarity; //1'b1;
            end

            if(row == I_v_pulse_end) begin
                vsync <= !I_v_pulse_polarity; //1'b0;
            end

            // handle last row
            if(row == I_last_row) begin
                // return to first row
                row <= 0;
                row_is_visible <= 1'b1;
            end

        end
       

    end





endmodule