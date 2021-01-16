module spu32_memory16_sim
    #(
        parameter SRAM_ADDR_BITS = 18
    )
    (
        input I_clk,
        input[3:0] I_request,
        input I_we,
        input I_ub,
        input I_lb,
        input[SRAM_ADDR_BITS-1:0] I_addr,
        input[15:0] I_data,
        output[15:0] O_data,
        output[3:0] O_ack,
        output O_stall
    );

    localparam RAMSIZE = SRAM_ADDR_BITS**2;

    reg[7:0] ram_lb[RAMSIZE-1:0];
    reg[7:0] ram_ub[RAMSIZE-1:0];

    reg[7:0] buf_lb, buf_ub;
    reg[15:0] read_buf;
    assign O_data = read_buf;

    reg[3:0] ack = 4'h0;
    assign O_ack = ack;


    reg we, ub, lb;
    reg[SRAM_ADDR_BITS-1:0] addr;
    reg[15:0] data;

    wire en = (I_request != 4'h0);
    reg work = 1'b0;

    // simulate mem operations between positive clock edges
    always @(negedge I_clk) begin
        if(work) begin
            if(we) begin
                // access lower byte
                if(lb) begin
                    ram_lb[addr] <= data[7:0];
                    $display("writing %h to lb, word %h", data[7:0], addr);
                end


                // access upper byte
                if(ub) begin
                    ram_ub[addr] <= data[15:8];
                    $display("writing %h to ub, word %h", data[15:8], addr);
                end
            end else begin
                read_buf[7:0] = ram_lb[addr];
                read_buf[15:8] = ram_ub[addr];
            end
        end
    end
    
    // "random" stalls to simulate VGA reads
    reg[31:0] stalls = 32'b01010010011100101010111011101010;
    always @(posedge I_clk) begin
        stalls <= {stalls[0],stalls[31:1]};
    end

    // simulate VGA requests
    assign O_stall = stalls[0];


    always @(posedge I_clk) begin
        work <= 1'b0;
        ack <= I_request;
        if(en) begin
            work <= 1'b1;
            addr <= I_addr;
            data <= I_data;
            we <= I_we;
            ub <= I_ub;
            lb <= I_lb;
        end
    end


endmodule