`default_nettype none
`include "./cpu/busdefs.vh"

module spu32_cpu_bus (
        // signals for CPU internals
        input I_en,
        input[2:0] I_op,
        input[31:0] I_addr,
        input[31:0] I_data,
        output[31:0] O_data,
        output O_busy,

        // signals to outside world
        output[31:0] O_bus_data,
        output[31:0] O_bus_addr,
        output O_bus_strobe,
        output O_bus_write,
        output O_bus_halfword,
        output O_bus_fullword,
        input[31:0] I_bus_data,
        input I_bus_wait
    );

    assign O_busy = I_bus_wait;
    assign O_bus_strobe = I_en;
    assign O_bus_data = I_data;
    assign O_bus_addr = I_addr;

    reg halfword, fullword, signextend, write;
    assign O_bus_halfword = halfword;
    assign O_bus_fullword = fullword;
    assign O_bus_write = write;

    // determine byte-length of bus operation
    always @(*) begin
        case(I_op)
            // half-word (16-bit) bus operations
            `BUSOP_READH, `BUSOP_READHU, `BUSOP_WRITEH: begin
                halfword = 1'b1;
                fullword = 1'b0;
            end

            // full-word (32-bit) bus operations
            `BUSOP_READW, `BUSOP_WRITEW: begin
                halfword = 1'b0;
                fullword = 1'b1;
            end

            // byte (8-bit) bus operations
            default: begin
                halfword = 1'b0;
                fullword = 1'b0;
            end
        endcase
    end

    // determine write signal
    always @(*) begin
        case(I_op)
            `BUSOP_WRITEB, `BUSOP_WRITEH, `BUSOP_WRITEW: begin
                write = 1'b1;
            end

            default: begin
                write = 1'b0;
            end
        endcase
    end

    // determine sign-extension (sign-extend or zero-extend)
    always @(*) begin
        case(I_op)
            `BUSOP_READB, `BUSOP_READH: begin
                signextend = 1'b1;
            end

            default: begin
                signextend = 1'b0;
            end
        endcase
    end

    reg[31:0] extendeddata;
    // extend incoming data as needed
    always @(*) begin
        case(I_op)
            `BUSOP_READB: begin
                extendeddata = {{24{I_bus_data[7]}}, I_bus_data[7:0]};
            end

            `BUSOP_READBU: begin
                extendeddata = {{24{1'b0}}, I_bus_data[7:0]};
            end

            `BUSOP_READH: begin
                extendeddata = {{16{I_bus_data[15]}}, I_bus_data[15:0]};
            end

            `BUSOP_READHU: begin
                extendeddata = {{16{1'b0}}, I_bus_data[15:0]};
            end

            default: begin
                extendeddata = I_bus_data[31:0];
            end
        endcase
    end

    assign O_data = extendeddata;



endmodule
 