`default_nettype none

module spu32_bus_wishbone32(
        input I_clk,
        input I_reset,
        // signals to CPU bus
        input I_strobe,
        input I_write,
        input I_halfword,
        input I_fullword,
        input[31:0] I_addr,
        input[31:0] I_data,
        output[31:0] O_data,
        output O_wait,
        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        input I_wb_ack,
        input I_wb_stall,
        input[31:0] I_wb_dat,
        output reg[29:0] O_wb_adr,
        output reg[31:0] O_wb_dat,
        output reg O_wb_cyc,
        output reg O_wb_stb,
        output reg O_wb_we,
        output reg[3:0] O_wb_sel // byte enables
    );

    reg busy = 0;
    assign O_wait = busy;

    reg[31:0] buffer = 32'h00000000;
    assign O_data = buffer;

    wire write = I_write;

    // wire up individual bytes from CPU (c-prefix)
    wire[7:0] c0 = I_data[7:0]; // least-significant byte
    wire[7:0] c1 = I_data[15:8];
    wire[7:0] c2 = I_data[23:16];
    wire[7:0] c3 = I_data[31:24]; // most-significant byte


    reg[8:0] byteenables;

    always @(*) begin
        case({I_addr[1:0], I_halfword, I_fullword})
            // byte access - always aligned
            {2'b00, 1'b0, 1'b0}: byteenables = 8'b0001_0000;
            {2'b01, 1'b0, 1'b0}: byteenables = 8'b0010_0000;
            {2'b10, 1'b0, 1'b0}: byteenables = 8'b0100_0000;
            {2'b11, 1'b0, 1'b0}: byteenables = 8'b1000_0000;
            // aligned halfword access
            {2'b00, 1'b1, 1'b0}: byteenables = 8'b0011_0000;
            {2'b01, 1'b1, 1'b0}: byteenables = 8'b0110_0000;
            {2'b10, 1'b1, 1'b0}: byteenables = 8'b1100_0000;
            // unaliged halfword access
            {2'b11, 1'b1, 1'b0}: byteenables = 8'b1000_0001;
            // aligned word access
            {2'b00, 1'b0, 1'b1}: byteenables = 8'b1111_0000;
            // unaliged word access
            {2'b01, 1'b0, 1'b1}: byteenables = 8'b1110_0001;
            {2'b10, 1'b0, 1'b1}: byteenables = 8'b1100_0011;
            {2'b11, 1'b0, 1'b1}: byteenables = 8'b1000_0111;
            default: byteenables = 8'b0;
        endcase
    end

    // on unaliged accesses a total of two words need to be accessed, one otherwise
    wire[1:0] word_target = (byteenables[3:0] != 4'b0000) ? 2'b10 : 2'b01;

    reg[1:0] ack_count = 2'b00;
    wire[1:0] ack_count_next = ack_count + 2'b01;

    reg[1:0] addr_count = 2'b00;
    wire[1:0] addr_count_next = addr_count + 2'b01;

    wire[29:0] bus_addr = I_addr[31:2] + {28'b0, addr_count};

    always @(posedge I_clk) begin
        busy <= I_strobe;
        O_wb_cyc <= I_strobe;

        O_wb_we <= 0;
        O_wb_stb <= (I_strobe && (addr_count != word_target || I_wb_stall ));

        if(I_strobe) begin
            // Mister Dalliard! We've been activated!
            O_wb_we <= write;

            if(ack_count != word_target) begin
                // we haven't yet received the proper number of ACKs, so we need to
                // output addresses and receive ACKs

                if(addr_count != word_target && !I_wb_stall) begin
                    O_wb_stb <= 1;
                    O_wb_adr <= bus_addr;

                    // output byte select signals
                    case(addr_count[0])
                        1'b0: O_wb_sel <= byteenables[7:4];
                        1'b1: O_wb_sel <= byteenables[3:0];
                    endcase

                    // put data on bus for current address
                    casez({I_addr[1:0], addr_count[0]})
                        // first word access
                        {2'b00, 1'b0}: O_wb_dat <= {c3, c2, c1, c0};
                        {2'b01, 1'b0}: O_wb_dat <= {c2, c1, c0, c0};
                        {2'b10, 1'b0}: O_wb_dat <= {c1, c0, c0, c0};
                        {2'b11, 1'b0}: O_wb_dat <= {c0, c0, c0, c0};
                        // unaliged accesses in second access phase
                        {2'b0?, 1'b1}: O_wb_dat <= {c3, c3, c3, c3}; // I_addr[1:0] == 2'b00 should never matter here
                        {2'b10, 1'b1}: O_wb_dat <= {c3, c3, c3, c2};
                        {2'b11, 1'b1}: O_wb_dat <= {c3, c3, c2, c1};
                    endcase

                    addr_count <= addr_count_next;
                end
            end

            if(I_wb_ack) begin
                // yay, ACK received, read data and put into buffer
                if(!I_write) begin
                    casez({I_addr[1:0], ack_count[0]})
                        // first word access
                        {2'b00, 1'b0}: buffer[31:0] <= I_wb_dat[31:0];
                        {2'b01, 1'b0}: buffer[23:0] <= I_wb_dat[31:8];
                        {2'b10, 1'b0}: buffer[15:0] <= I_wb_dat[31:16];
                        {2'b11, 1'b0}: buffer[7:0] <= I_wb_dat[31:24];
                        // second word access
                        {2'b0?, 1'b1}: buffer[31:24] <= I_wb_dat[7:0];
                        {2'b10, 1'b1}: buffer[31:16] <= I_wb_dat[15:0];
                        {2'b11, 1'b1}: buffer[31:8] <= I_wb_dat[23:0];
                    endcase
                end
                ack_count <= ack_count_next;

                if(ack_count_next == word_target) begin
                    // received the correct number of ACKs, prepare for next request
                    busy <= 0;
                    ack_count <= 0;
                    addr_count <= 0;
                end
            end

        end

        if(I_reset) begin
            addr_count <= 2'b00;
            ack_count <= 2'b00;
        end

    end
    
endmodule
