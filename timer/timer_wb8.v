module timer_wb8
    #(
        parameter CLOCKFREQ = 25000000
    )
    (
        // Wishbone signals
        input[2:0] I_wb_adr,
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat,
        // interrupt output
        output O_interrupt
    );

    localparam MILLICYCLES = (CLOCKFREQ / 1000) - 1;
    localparam COUNTERWIDTH = $clog2(CLOCKFREQ / 1000);

    reg[(COUNTERWIDTH-1):0] cycles = 0;
    reg[31:0] milliseconds = 0;
    reg[31:0] milliseconds_interrupt = 0;
    reg[23:0] bufferedval = 0;
    reg interrupt_latched = 0;
    reg interrupt_armed = 0;

    assign O_interrupt = interrupt_latched;

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
                    4: begin
                        milliseconds_interrupt[7:0] <= I_wb_dat;
                    end

                    5: begin
                        milliseconds_interrupt[15:8] <= I_wb_dat;
                    end

                    6: begin
                        milliseconds_interrupt[23:16] <= I_wb_dat;
                    end

                    7: begin
                        // arm timer interrupt
                        interrupt_armed <= 1;
                        milliseconds_interrupt[31:24] <= I_wb_dat;
                    end
                endcase

            end else begin
                case(I_wb_adr)
                    // first four bytes: current time
                    0: begin
                        bufferedval <= milliseconds[31:8];
                        O_wb_dat <= milliseconds[7:0];
                    end

                    1: begin 
                        O_wb_dat <= bufferedval[7:0];
                    end

                    2: begin
                        O_wb_dat <= bufferedval[15:8];
                    end

                    3: begin
                        O_wb_dat <= bufferedval[23:16];
                    end

                    // next four bytes: interrupt time target
                    4: begin
                        // reading the interrupt time target resets the interrupt request
                        interrupt_latched <= 0;
                        O_wb_dat <= milliseconds_interrupt[7:0];
                    end

                    5: begin
                        O_wb_dat <= milliseconds_interrupt[15:8];
                    end

                    6: begin
                        O_wb_dat <= milliseconds_interrupt[23:16];
                    end

                    7: begin
                        O_wb_dat <= milliseconds_interrupt[31:24];
                    end

                endcase
            end
        end
    end


endmodule