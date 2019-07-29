module irdecoder_wb8
    #(
        parameter CLOCKFREQ = 25000000
    )
    (
        // Wishbone signals
        input[2:0] I_wb_adr,
        input I_wb_clk,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output reg[7:0] O_wb_dat,
        // connection to infrared-receiver
        input I_ir_signal
    );

    /*
    * A decoder for infrared remotes using the NEC protocol
    */

    localparam MICROCYCLES = (CLOCKFREQ / 1000000) - 1;
    localparam COUNT_0 = 400 * MICROCYCLES; // a zero is 563 µs long
    localparam COUNT_1 = 1400 * MICROCYCLES; // a one is 1688 µs long
    localparam COUNT_SHORTPAUSE = 2000 * MICROCYCLES; // a short pause is 2.3 ms long
    localparam COUNT_LONGPAUSE = 4000 * MICROCYCLES; // a long pause is 4.5 ms long
    localparam COUNT_STOP = 8000 * MICROCYCLES; // assume that the message ended after 8 ms without signal change

    localparam DATA_START = 5'b00000;
    localparam DATA_0 = 5'b00001;
    localparam DATA_1 = 5'b00010;
    localparam DATA_SHORTPAUSE = 5'b00100;
    localparam DATA_LONGPAUSE = 5'b01000;
    localparam DATA_STOP = 5'b10000;

    reg[4:0] decdata = DATA_START;

    reg[31:0] irdata = 0;
    reg[23:0] readbuffer = 0;
    reg[2:0] indat = 0;
    reg[$clog2(COUNT_STOP):0] counter = 0;
    reg[5:0] bitcounter = 0;

    wire data_valid;
    assign data_valid = (bitcounter == 32);

    always @(posedge I_wb_clk) begin

        indat <= {indat[1:0], I_ir_signal};

        if(indat == 3'b000) begin

            if(counter != 0) begin
                if(decdata == DATA_0 || decdata == DATA_1) begin
                    irdata <= {irdata[30:0], decdata[1]};
                    bitcounter <= bitcounter + 1;
                end else if(decdata == DATA_SHORTPAUSE) begin
                    // repeat signal
                    bitcounter <= 32;
                end
            end

            counter <= 0;
            decdata <= DATA_START;

        end else if(indat == 3'b111) begin
            if(decdata != DATA_STOP) begin
                counter <= counter + 1;
            end

            if(counter == COUNT_0) begin
                decdata <= DATA_0;
            end else if(counter == COUNT_1) begin
                decdata <= DATA_1;
            end else if(counter == COUNT_SHORTPAUSE) begin
                decdata <= DATA_SHORTPAUSE;
            end else if(counter == COUNT_LONGPAUSE) begin
                decdata <= DATA_LONGPAUSE;
            end else if(counter == COUNT_STOP) begin
                decdata <= DATA_STOP;
                bitcounter <= 0;
            end
        end

        if(I_wb_stb) begin
            if(I_wb_we) begin
                // writes are used to acknowledge and prepare for new data
                bitcounter <= 0;
            end else begin
                case(I_wb_adr)
                    0 : begin
                        readbuffer <= data_valid ? irdata[23:0] : 24'h000000;
                        O_wb_dat <= data_valid ? irdata[31:24] : 8'h00;
                    end
                     
                    1 : O_wb_dat <= readbuffer[23:16];
                    2 : O_wb_dat <= readbuffer[15:8];
                    default: O_wb_dat <= readbuffer[7:0];
                endcase;
            end
        end

        O_wb_ack <= I_wb_stb;
    end


endmodule