`default_nettype none
`include "./cpu/busdefs.vh"

module spu32_cpu_bus_wb8(
        input I_en,
        input[2:0] I_op,
        input[31:0] I_addr,
        input[31:0] I_data,
        output[31:0] O_data,
        output O_busy,

        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        input CLK_I,
        input ACK_I,
        input STALL_I,
        input[7:0] DAT_I,
        input RST_I,
        output reg[31:0] ADR_O,
        output reg[7:0] DAT_O,
        output reg CYC_O,
        output reg STB_O,
        output reg WE_O
    );

    reg[31:0] buffer;
    assign O_data = buffer;

    reg busy = 0;
    assign O_busy = busy;

    reg[2:0] addrcnt = 0, ackcnt = 0, byte_target = 0;
    wire[2:0] addrcnt_next, ackcnt_next;
    
    // do not progress to next address if STALL is asserted
    assign addrcnt_next = addrcnt + 1;
    assign ackcnt_next = ackcnt + 1;

    wire[31:0] busaddr;
    assign busaddr = I_addr + {{29{1'b0}}, addrcnt};
    reg signextend = 0;
    reg write = 0;

    reg mysign = 0;


    always @(*) begin
        // determine number of bytes to be processed
        case(I_op)
            `BUSOP_READW, `BUSOP_WRITEW: byte_target = 4;
            `BUSOP_READH, `BUSOP_READHU, `BUSOP_WRITEH: byte_target = 2;
            default: byte_target = 1;
        endcase

        // determine if sign extension is requested
        case(I_op)
            `BUSOP_READBU, `BUSOP_READHU: signextend = 0;
            default: signextend = 1;
        endcase

        // determine if a write operation is requested
        case(I_op)
            `BUSOP_WRITEB, `BUSOP_WRITEH, `BUSOP_WRITEW: write = 1;
            default: write = 0;
        endcase
    end

    always @(*) begin
        mysign = DAT_I[7] & signextend;
    end


    always @(posedge CLK_I) begin
        busy <= I_en;
        CYC_O <= I_en;

        WE_O <= 0;
        STB_O <= (I_en && (addrcnt != byte_target || STALL_I ));

        if(I_en) begin
            // if enabled, act
            WE_O <= write;

            if(ackcnt != byte_target) begin
                // we haven't yet received the proper number of ACKs, so we need to
                // output addresses and receive ACKs
                if(addrcnt != byte_target && !STALL_I) begin
                    STB_O <= 1;
                    ADR_O <= busaddr;

                    // put data on bus for current address
                    case(addrcnt)
                        0:			DAT_O <= I_data[7:0];
                        1: 			DAT_O <= I_data[15:8];
                        2: 			DAT_O <= I_data[23:16];
                        default:	DAT_O <= I_data[31:24];
                    endcase

                    addrcnt <= addrcnt_next;
                end

                if(ACK_I) begin
                    // yay, ACK received, read data and put into buffer
                    case (ackcnt)
                        0:			buffer <= {{24{mysign}}, DAT_I};	
                        1:			buffer[31:8] <= {{16{mysign}}, DAT_I};	
                        2:			buffer[23:16] <= DAT_I;
                        default: begin
                            buffer[31:24] <= DAT_I;
                        end
                    endcase
                    ackcnt <= ackcnt_next;

                    if(ackcnt_next == byte_target) begin
                        // received the correct number of ACKs, prepare for next request
                        busy <= 0;
                        ackcnt <= 0;
                        addrcnt <= 0;
                    end
                end

            end

        end

        if(RST_I) begin
            ackcnt <= 0;
            addrcnt <= 0;
        end

    end


endmodule
