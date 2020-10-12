`default_nettype none


module vga_pixelpipe_test
    #(
        parameter COLBITS = 10,
        parameter ROWBITS = 10
    )
    (
        input I_clk,
        input[COLBITS-1:0] I_col,
        input[ROWBITS-1:0] I_row,
        input I_vsync,
        input I_hsync,
        input I_visible,

        output[7:0] O_palette_idx,
        output O_vsync,
        output O_hsync,
        output O_visible
    );

    localparam RED = 8'h04;
    localparam GREEN = 8'h02;
    localparam BLUE = 8'h01;

    reg vsync, hsync, visible;
    assign O_vsync = vsync;
    assign O_hsync = hsync;
    assign O_visible = visible;

    reg[7:0] idx;
    assign O_palette_idx = idx;


    always @(posedge I_clk) begin

        vsync <= I_vsync;
        hsync <= I_hsync;
        visible <= I_visible;

        idx <= GREEN;
        if(!I_row[3]) begin
            if(I_col[3]) begin
                idx <= BLUE;
            end
        end else begin
            if(!I_col[3]) begin
                idx <= RED;
            end
        end

    end

endmodule