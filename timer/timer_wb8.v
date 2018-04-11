module timer_wb8
    #(
        parameter CLOCKFREQ = 25000000
    )
    (
        // naming according to Wisbhone B4 spec
        input[1:0] ADR_I,
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        // Wishbone outputs
        output reg ACK_O,
        output reg[7:0] DAT_O
    );

    localparam MILLICYCLES = (CLOCKFREQ / 1000) - 1;
    localparam COUNTERWIDTH = $clog2(CLOCKFREQ / 1000);

    reg[(COUNTERWIDTH-1):0] cycles = 0;
    reg[31:0] milliseconds = 0;
    reg[23:0] bufferedval = 0;



    always @(posedge CLK_I) begin
        cycles <= cycles + 1;

        if(cycles == MILLICYCLES) begin
            milliseconds <= milliseconds + 1;
            cycles <= 0;
        end


        if(STB_I) begin
            case(ADR_I)
                0: begin
                    bufferedval <= milliseconds[31:8];
                    DAT_O <= milliseconds[7:0];
                end

                1: begin 
                    DAT_O <= bufferedval[7:0];
                end

                2: begin
                    DAT_O <= bufferedval[15:8];
                end

                3: begin
                    DAT_O <= bufferedval[23:16];
                end

            endcase

            ACK_O <= 1;
        end else begin
            ACK_O <= 0;
        end
    end


endmodule