`default_nettype none

module vga_mode_generator
    #(
        parameter COLBITS = 10,
        parameter ROWBITS = 10
    )
    (
        input I_mode,
        output reg [COLBITS-1:0] O_last_visible_col, O_h_pulse_start, O_h_pulse_end, O_last_col,
        output reg [ROWBITS-1:0] O_last_visible_row, O_v_pulse_start, O_v_pulse_end, O_last_row,
        output reg O_v_pulse_polarity, O_h_pulse_polarity
    );


    localparam mode0_h_visible = 640;
    localparam mode0_h_front_porch = 16;
    localparam mode0_h_pulse = 96;
    localparam mode0_h_back_porch = 48;
    localparam mode0_v_visible = 480;
    localparam mode0_v_front_porch = 10;
    localparam mode0_v_pulse = 2;
    localparam mode0_v_back_porch = 33;
    localparam mode0_v_pulse_polarity = 0;
    localparam mode0_h_pulse_polarity = 0;


    localparam mode1_h_visible = 640;
    localparam mode1_h_front_porch = 16;
    localparam mode1_h_pulse = 96;
    localparam mode1_h_back_porch = 48;
    localparam mode1_v_visible = 400;
    localparam mode1_v_front_porch = 1;
    localparam mode1_v_pulse = 3;
    localparam mode1_v_back_porch = 38;
    localparam mode1_v_pulse_polarity = 1;
    localparam mode1_h_pulse_polarity = 0;


    always @(*) begin
        if(I_mode == 1'b0) begin
            O_last_visible_col = mode0_h_visible - 1;
            O_h_pulse_start = mode0_h_visible + mode0_h_front_porch - 1;
            O_h_pulse_end = mode0_h_visible + mode0_h_front_porch + mode0_h_pulse - 1;
            O_last_col = mode0_h_visible + mode0_h_front_porch + mode0_h_pulse + mode0_h_back_porch - 1;

            O_last_visible_row = mode0_v_visible - 1;
            O_v_pulse_start = mode0_v_visible + mode0_v_front_porch - 1;
            O_v_pulse_end = mode0_v_visible + mode0_v_front_porch + mode0_v_pulse - 1;
            O_last_row = mode0_v_visible + mode0_v_front_porch + mode0_v_pulse + mode0_v_back_porch - 1;

            O_v_pulse_polarity = mode0_v_pulse_polarity;
            O_h_pulse_polarity = mode0_h_pulse_polarity;
        end else begin
            O_last_visible_col = mode1_h_visible - 1;
            O_h_pulse_start = mode1_h_visible + mode1_h_front_porch - 1;
            O_h_pulse_end = mode1_h_visible + mode1_h_front_porch + mode1_h_pulse - 1;
            O_last_col = mode1_h_visible + mode1_h_front_porch + mode1_h_pulse + mode1_h_back_porch - 1;

            O_last_visible_row = mode1_v_visible - 1;
            O_v_pulse_start = mode1_v_visible + mode1_v_front_porch - 1;
            O_v_pulse_end = mode1_v_visible + mode1_v_front_porch + mode1_v_pulse - 1;
            O_last_row = mode1_v_visible + mode1_v_front_porch + mode1_v_pulse + mode1_v_back_porch - 1;

            O_v_pulse_polarity = mode1_v_pulse_polarity;
            O_h_pulse_polarity = mode1_h_pulse_polarity;
        end
    end


endmodule