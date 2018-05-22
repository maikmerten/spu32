module timer_wb8
    #(
        parameter CLOCKFREQ = 25000000
    )
    (
        // naming according to Wisbhone B4 spec
        input[2:0] ADR_I,
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        // Wishbone outputs
        output reg ACK_O,
        output reg[7:0] DAT_O,
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

    always @(posedge CLK_I) begin
        cycles <= cycles + 1;

        if(cycles == MILLICYCLES) begin
            milliseconds <= milliseconds + 1;
            cycles <= 0;
        end

        if(milliseconds == milliseconds_interrupt && interrupt_armed) begin
            interrupt_latched <= 1;
            interrupt_armed <= 0;
        end

        if(STB_I) begin
            if(WE_I) begin
                case(ADR_I)
                    // for now only the interrupt time target is writable
                    4: begin
                        milliseconds_interrupt[7:0] <= DAT_I;
                    end

                    5: begin
                        milliseconds_interrupt[15:8] <= DAT_I;
                    end

                    6: begin
                        milliseconds_interrupt[23:16] <= DAT_I;
                    end

                    7: begin
                        // arm timer interrupt
                        interrupt_armed <= 1;
                        milliseconds_interrupt[31:24] <= DAT_I;
                    end
                endcase

            end else begin
                case(ADR_I)
                    // first four bytes: current time
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

                    // next four bytes: interrupt time target
                    4: begin
                        // reading the interrupt time target resets the interrupt request
                        interrupt_latched <= 0;
                        DAT_O <= milliseconds_interrupt[7:0];
                    end

                    5: begin
                        DAT_O <= milliseconds_interrupt[15:8];
                    end

                    6: begin
                        DAT_O <= milliseconds_interrupt[23:16];
                    end

                    7: begin
                        DAT_O <= milliseconds_interrupt[31:24];
                    end

                endcase
            end

            ACK_O <= 1;
        end else begin
            ACK_O <= 0;
        end
    end


endmodule