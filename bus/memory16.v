module spu32_bus_memory16
    #(
        parameter SRAM_ADDR_BITS = 18
    )
    (
        input I_clk,
        // signals to CPU
        input[31:0] I_data,
        input[31:0] I_addr,
        input I_strobe,
        input I_write,
        input I_halfword,
        input I_fullword,
        output[31:0] O_data,
        output O_wait,
        // signals to SRAM
        input[15:0] I_sram_data,
        output[15:0] O_sram_data,
        output[SRAM_ADDR_BITS-1:0] O_sram_addr,
        output[3:0] O_sram_request,
        input[3:0] I_sram_ack,
        input I_sram_stall,
        output O_sram_we,
        output O_sram_ub,
        output O_sram_lb
    );

// buffer for data read from SRAM
reg[31:0] buffer;
assign O_data = buffer;


// wait-flag to bus-logic
reg busy = 1'b0;
assign O_wait = busy;


assign O_sram_we = I_write;


// counter for word-accesses. In worst case (unaligned 32-bit access), we need to process
// three 16-bit words
reg[1:0] wordcnt = 2'd0;

// number fo word-accesses to be performed
reg[1:0] wordtarget;

// is this an unaligned memory access?
wire unaligned = I_addr[0];

// compute and output word-address to SRAM
wire[SRAM_ADDR_BITS-1:0] sram_addr = I_addr[SRAM_ADDR_BITS:1] + {{(SRAM_ADDR_BITS-2){1'b0}}, wordcnt};
assign O_sram_addr = sram_addr;


reg[1:0] byte_enables;
assign {O_sram_lb, O_sram_ub} = byte_enables;

always @(*) begin
    case({I_halfword, I_fullword, unaligned, wordcnt})
        // byte-accesses
        {3'b000, 2'd0}: byte_enables = 2'b10; // even address, access 0
        {3'b001, 2'd0}: byte_enables = 2'b01; // odd address, access 0

        // halfword-accesses
        {3'b100, 2'd0}: byte_enables = 2'b11; // aligned, access 0
        {3'b101, 2'd0}: byte_enables = 2'b01; // unaligned, access 0
        {3'b101, 2'd1}: byte_enables = 2'b10; // unaligned, access 1

        // word-accessess
        {3'b010, 2'd0}: byte_enables = 2'b11; // aligned, access 0
        {3'b010, 2'd1}: byte_enables = 2'b11; // aligned, access 1
        {3'b011, 2'd0}: byte_enables = 2'b01; // unaligned, access 0
        {3'b011, 2'd1}: byte_enables = 2'b11; // unaligned, access 1
        {3'b011, 2'd2}: byte_enables = 2'b10; // unaligned, access 2

        default: byte_enables = 2'b00;
    endcase
end


// request types. request[3] denotes that further word-accessses are needed
localparam BYTE_A_0 = {1'b0, 3'b001};
localparam BYTE_U_0 = {1'b0, 3'b010};
localparam HALF_A_0 = {1'b0, 3'b011};
localparam HALF_U_0 = {1'b1, 3'b001};
localparam HALF_U_1 = {1'b0, 3'b100};
localparam FULL_A_0 = {1'b1, 3'b010};
localparam FULL_A_1 = {1'b0, 3'b101};
localparam FULL_U_0 = {1'b1, 3'b011};
localparam FULL_U_1 = {1'b1, 3'b100};
localparam FULL_U_2 = {1'b0, 3'b110};


reg requestpause = 1'b1;
reg[3:0] request;
always @(*) begin
    case({I_halfword, I_fullword, unaligned, wordcnt})
        // byte-accesses
        {3'b000, 2'd0}: request = BYTE_A_0; // even address, access 0
        {3'b001, 2'd0}: request = BYTE_U_0; // odd address, access 0

        // halfword-accesses
        {3'b100, 2'd0}: request = HALF_A_0; // aligned, access 0
        {3'b101, 2'd0}: request = HALF_U_0; // unaligned, access 0
        {3'b101, 2'd1}: request = HALF_U_1; // unaligned, access 1

        // word-accessess
        {3'b010, 2'd0}: request = FULL_A_0; // aligned, access 0
        {3'b010, 2'd1}: request = FULL_A_1; // aligned, access 1
        {3'b011, 2'd0}: request = FULL_U_0; // unaligned, access 0
        {3'b011, 2'd1}: request = FULL_U_1; // unaligned, access 1
        {3'b011, 2'd2}: request = FULL_U_2; // unaligned, access 2

        default: request = 4'h0;
    endcase

    if(requestpause | !I_strobe) begin
        request = 4'h0;
    end
end
assign O_sram_request = request;
wire last_ack = (I_sram_ack[2:0] != 3'b000 && !I_sram_ack[3] && !I_sram_stall);

reg[15:0] outdat;
assign O_sram_data = outdat;
always @(*) begin
    case({I_halfword, I_fullword, unaligned, wordcnt})
        // byte-accesses
        {3'b000, 2'd0}: outdat = {I_data[7:0], I_data[7:0]};
        {3'b001, 2'd0}: outdat = {I_data[7:0], I_data[7:0]};

        // halfword-accesses
        {3'b100, 2'd0}: outdat = I_data[15:0];
        {3'b101, 2'd0}: outdat = {I_data[7:0], I_data[7:0]};
        {3'b101, 2'd1}: outdat = {I_data[15:8], I_data[15:8]};

        // word-accessess
        {3'b010, 2'd0}: outdat = I_data[15:0];
        {3'b010, 2'd1}: outdat = I_data[31:16];
        {3'b011, 2'd0}: outdat = {I_data[7:0], I_data[7:0]};
        {3'b011, 2'd1}: outdat = I_data[23:8];
        {3'b011, 2'd2}: outdat = {I_data[31:24], I_data[31:24]};

        default: outdat = {I_data[7:0], I_data[7:0]};
    endcase
end

always @(posedge I_clk) begin
    // when selected, signal that this unit is working
    busy <= I_strobe;

    if(I_strobe) begin
        // put data read from SRAM into buffer
        case(I_sram_ack)
            // byte-accesses
            BYTE_A_0: buffer[7:0] <= I_sram_data[7:0];
            BYTE_U_0: buffer[7:0] <= I_sram_data[15:8];

            // halfword-accesses
            HALF_A_0: buffer[15:0] <= I_sram_data[15:0];
            HALF_U_0: buffer[7:0] <= I_sram_data[15:8];
            HALF_U_1: buffer[15:8] <= I_sram_data[7:0];

            // word-accessess
            FULL_A_0: buffer[15:0] <= I_sram_data[15:0];
            FULL_A_1: buffer[31:16] <= I_sram_data[15:0];
            FULL_U_0: buffer[7:0] <= I_sram_data[15:8];
            FULL_U_1: buffer[23:8] <= I_sram_data[15:0];
            FULL_U_2: buffer[31:24] <= I_sram_data[7:0];
        endcase

        if(last_ack) begin
            busy <= 1'b0;
        end
    end
end


always @(negedge I_clk) begin
    if(!I_sram_stall) begin
        if(I_sram_ack[3]) begin
            // proceed to next word address if next word is requested
            wordcnt <= wordcnt + 2'd1;
        end else begin
            // if ack[3] is zero, then the last access was ACK'ed, prepare for next request
            wordcnt <= 2'd0;
        end
    end

    requestpause <= last_ack;
end


endmodule