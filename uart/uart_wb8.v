module uart_wb8
    #(
        parameter BAUDRATE = 115200,
        parameter CLOCKFREQ = 25000000
    )
    (
        // naming according to Wisbhone B4 spec
        input[1:0] ADR_I, // data register, receive status, send status
        input CLK_I,
        input[7:0] DAT_I,
        input STB_I,
        input WE_I,
        // serial input (RX)
        input I_rx,
        // Wishbone outputs
        output reg ACK_O,
        output reg[7:0] DAT_O,
        // serial output (TX)
        output reg O_tx
    );

    localparam baudclocks = CLOCKFREQ/BAUDRATE;

    localparam READ_IDLE = 0;
    localparam READ_READ = 1;
    reg readstate = READ_IDLE;

    localparam WRITE_IDLE = 0;
    localparam WRITE_WRITE = 1;
    reg writestate = WRITE_IDLE;

    reg[7:0] inputbuf, readbuf, writebuf = 0;
    reg[2:0] edgefilter = 3'b111;
    
    reg[3:0] readbitcnt, writebitcnt = 0;
    reg[9:0] readclkcnt, writeclkcnt = 0;

    reg read_ready, write_ready, do_write = 0;

    always @(posedge CLK_I) begin

        case (readstate)
            READ_IDLE: begin
                edgefilter <= {I_rx, edgefilter[2:1]};
                if({I_rx, edgefilter} == 0) begin
                    readstate <= READ_READ;
                    readclkcnt <= 0;
                    readbitcnt <= 0;
                    edgefilter <= 3'b111;
                end            
            end 

            READ_READ: begin
                // sample mid-baud
                if(readclkcnt == baudclocks/2) begin
                    if(readbitcnt != 9) begin
                        inputbuf <= {I_rx, inputbuf[7:1]};    
                    end else begin
                        readbuf <= inputbuf;
                        read_ready <= 1;
                        readstate <= READ_IDLE;
                    end
                    readbitcnt <= readbitcnt + 1;
                end

                readclkcnt <= readclkcnt + 1;
                if(readclkcnt == baudclocks) readclkcnt <= 0;
            end
        endcase

        case(writestate)
            WRITE_IDLE: begin
                O_tx <= 1; // output high on idle
                if(do_write) begin
                  writestate <= WRITE_WRITE;
                  writeclkcnt <= 0;
                  writebitcnt <= 0;
                  O_tx <= 0; // start bit
                end
              
            end

            WRITE_WRITE: begin
                writeclkcnt <= writeclkcnt + 1;
                if(writeclkcnt == (baudclocks - 1)) begin
                    // write next bit
                    writeclkcnt <= 0;
                    writebitcnt <= writebitcnt + 1;
                    if(writebitcnt == 9) begin
                        writestate <= WRITE_IDLE;
                        do_write <= 0;
                    end
                    O_tx <= writebuf[0];
                    writebuf <= {1'b1, writebuf[7:1]};
                  
                end
              
            end
        endcase

        if(STB_I) begin
            case(ADR_I)
                0: begin // data register
                    if(WE_I) begin
                        writebuf <= DAT_I;
                        do_write <= 1;
                    end else begin
                        DAT_O <= readbuf;
                        read_ready <= 0;
                    end
                end

                1: begin 
                    DAT_O <= {7'b0, read_ready}; // status register: receive
                end

                default: begin // status register: send
                    DAT_O <= {7'b0, !do_write};
                end

            endcase

            ACK_O <= 1;
        end else begin
            ACK_O <= 0;
        end

    end

endmodule