`default_nettype none

module timer_wb32
    #(
        parameter CLOCKFREQ = 25000000
    )
    (
        // Wishbone signals
        input I_wb_adr,
        input[3:0] I_wb_sel,
        input I_wb_clk,
        input[31:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[31:0] O_wb_dat,
        // interrupt output
        output O_interrupt
    );

    localparam MILLICYCLES = (CLOCKFREQ / 1000) - 1;
    localparam COUNTERWIDTH = $clog2(CLOCKFREQ / 1000);

    reg[(COUNTERWIDTH-1):0] cycles = 0;
    reg[31:0] milliseconds = 0;
    reg[31:0] milliseconds_interrupt = 0;
    reg interrupt_latched = 0;
    reg interrupt_armed = 0;

    assign O_interrupt = interrupt_latched;

    wire wordaccess = (I_wb_sel == 4'b1111);

    always @(posedge I_wb_clk) begin
        O_wb_ack <= I_wb_stb;

        cycles <= cycles + 1;

        if(cycles == MILLICYCLES) begin
            milliseconds <= milliseconds + 1;
            cycles <= 0;
        end

        if(milliseconds == milliseconds_interrupt && interrupt_armed) begin
            interrupt_latched <= 1;
            interrupt_armed <= 0;
        end

        if(I_wb_stb) begin
            if(I_wb_we) begin
                case(I_wb_adr)
                    // for now only the interrupt time target is writable
                    1: begin
                        // arm timer interrupt, but only for complete words
                        if(wordaccess) begin
                            interrupt_armed <= 1;
                            milliseconds_interrupt <= I_wb_dat;
                        end
                    end
                endcase

            end else begin
                case(I_wb_adr)
                    // first four-byte word: current time
                    0: begin
                        O_wb_dat <= milliseconds;
                    end


                    // next four-byte word: interrupt time target
                    1: begin
                        // reading the interrupt time target resets the interrupt request
                        interrupt_latched <= 0;
                        O_wb_dat <= milliseconds_interrupt;
                    end

                endcase
            end
        end
    end


endmodule