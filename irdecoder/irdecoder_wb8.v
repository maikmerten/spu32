module irdecoder_wb8
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
        // connection to infrared-receiver
        input I_ir_signal
    );

    /*
    * A decoder for infrared remotes using the NEC protocol
    */

    localparam MICROCYCLES = (CLOCKFREQ / 1000000) - 1;
    localparam MAXCOUNT = 68 * 1000 * MICROCYCLES; // a message is at most 68 ms long
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
    reg[2:0] indat = 0;
    reg[$clog2(COUNT_STOP):0] counter = 0;
    reg[5:0] bitcounter = 0;

    wire data_valid;
    assign data_valid = (bitcounter == 32);

    always @(posedge CLK_I) begin

        indat <= {indat[1:0], I_ir_signal};
 

        if(indat == 3'b000) begin

            if(counter != 0) begin

                if(decdata == DATA_0) begin
                    irdata <= {irdata[30:0], 1'b0};
                    bitcounter <= bitcounter + 1;
                end else if(decdata == DATA_1) begin
                    irdata <= {irdata[30:0], 1'b1};
                    bitcounter <= bitcounter + 1;
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

        if(STB_I) begin

            if(WE_I) begin
                case(ADR_I)
                    0 : irdata[31:24] <= DAT_I;
                    1 : irdata[23:16] <= DAT_I;
                    2 : irdata[15:8] <= DAT_I;
                    default: irdata[7:0] <= DAT_I;
                endcase
            end else begin
                case(ADR_I)
                    0 : DAT_O <= data_valid ? irdata[31:24] : 8'h00;
                    1 : DAT_O <= data_valid ? irdata[23:16] : 8'h00;
                    2 : DAT_O <= data_valid ? irdata[15:8] : 8'h00;
                    default: DAT_O <= data_valid ? irdata[7:0] : 8'h00;
                endcase;
            end
            

            ACK_O <= 1;
        end else begin
            ACK_O <= 0;
        end
    end


endmodule