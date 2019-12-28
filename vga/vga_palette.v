module vga_palette (
        input I_clk,
        input[31:0] I_palette_update,
        input I_update_request,
        input[7:0] I_palette_idx,

        output O_update_ack,
        output reg[23:0] O_rgb
    );

    reg[23:0] palette [255:0];
    initial $readmemh("vga/vga_palette_256.dat", palette, 0, 255);

    reg update_ack = 0;
    wire[7:0] update_idx;
    assign update_idx = I_palette_update[31:24];
    wire[23:0] update_rgb;
    assign update_rgb = I_palette_update[23:0];

    assign O_update_ack = update_ack;

    wire write;
    assign write = (update_ack != I_update_request);

    always @(posedge I_clk) begin
        O_rgb <= palette[I_palette_idx];
        if(write) begin
            palette[update_idx] <= update_rgb;
        end

        update_ack <= I_update_request;
    end



endmodule