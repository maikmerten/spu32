`default_nettype none
`include "./bus/memory16.v"
`include "./bus/tests/memory16_sim.v"

module memory16_tb();


    parameter CLKPERIOD = 2;
    parameter SRAM_ADDR_BITS = 18;

    reg clk = 0;
    always # (CLKPERIOD / 2) clk = !clk;
    
    integer error = 0;
    always @(error) begin
        if(error !== 0) begin
            $display("!!! FINISHING WITH ERROR, TESTCASE %0d FAILED!", error);
            # (CLKPERIOD * 2);
            $finish_and_return(1);
        end
    end

    integer test = 0;


    reg[31:0] cpu_data, cpu_addr;
    reg cpu_strobe, cpu_write, cpu_halfword, cpu_fullword, cpu_reset;
    wire[31:0] bus_data;
    wire bus_wait, bus_sram_we, bus_sram_ub, bus_sram_lb;
    wire[3:0] bus_sram_request;
    wire[15:0] bus_sram_data;
    wire[SRAM_ADDR_BITS-1:0] bus_sram_addr;

    wire[3:0] sram_ack;
    wire sram_stall;
    wire[15:0] sram_data;

    spu32_bus_memory16 bus_memory_inst
    (
        .I_clk(clk),
        // signals to CPU
        .I_data(cpu_data),
        .I_addr(cpu_addr),
        .I_strobe(cpu_strobe),
        .I_write(cpu_write),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .O_data(bus_data),
        .O_wait(bus_wait),
        // signals to SRAM
        .I_sram_ack(sram_ack),
        .I_sram_stall(sram_stall),
        .I_sram_data(sram_data),
        .O_sram_data(bus_sram_data),
        .O_sram_addr(bus_sram_addr),
        .O_sram_request(bus_sram_request),
        .O_sram_we(bus_sram_we),
        .O_sram_ub(bus_sram_ub),
        .O_sram_lb(bus_sram_lb)
    );

    spu32_memory16_sim memory_sim_inst
    (
        .I_clk(clk),
        .I_request(bus_sram_request),
        .I_we(bus_sram_we),
        .I_ub(bus_sram_ub),
        .I_lb(bus_sram_lb),
        .I_addr(bus_sram_addr),
        .I_data(bus_sram_data),
        .O_data(sram_data),
        .O_ack(sram_ack),
        .O_stall(sram_stall)
    );

    task do_assert(
            input[31:0] I_dat1,
            input[31:0] I_dat2,
            input integer I_error
        );
        begin
            if(I_dat1 != I_dat2) begin
                error = I_error;
            end
        end
    endtask

    task do_write(
            input[31:0] I_addr,
            input[1:0] I_size,
            input[31:0] I_data
        );
        begin
            cpu_addr = I_addr;
            cpu_strobe = 1;
            cpu_data = I_data;
            cpu_halfword = I_size[1];
            cpu_fullword = I_size[0];
            cpu_write = 1;

            @(negedge bus_wait)
            @(negedge clk)
            cpu_write = 0;
        end
    endtask


    task do_read(
            input[31:0] I_addr,
            input[1:0] I_size,
            output[31:0] O_data
        );
        begin
            cpu_addr = I_addr;
            cpu_strobe = 1;
            cpu_halfword = I_size[1];
            cpu_fullword = I_size[0];
            cpu_write = 0;

            @(negedge bus_wait)
            @(negedge clk)
            O_data = bus_data;
        end
    endtask

    reg[31:0] data,tmp;

    localparam BYTE = 2'b00;
    localparam HALF = 2'b10;
    localparam FULL = 2'b01;

    integer i;
    
    initial begin
        $dumpfile("memorybus_tb.lxt");
        $dumpvars(0, test, clk, cpu_data, cpu_addr, cpu_strobe, cpu_write, cpu_halfword, cpu_fullword, bus_data, bus_wait, sram_ack, sram_stall, sram_data, bus_sram_data, bus_sram_addr,bus_sram_request, bus_sram_we, bus_sram_ub, bus_sram_lb, bus_memory_inst.wordtarget, bus_memory_inst.wordcnt);
        
        data = 32'h76543210;
        
        @(negedge clk)

        for(i = 0; i < 7; i = i + 1) begin
            

            do_write(0, FULL, data);
            do_read(0, FULL, tmp);
            $display("read data: %h", tmp);
            do_assert(data, tmp, 1);


            do_write(1, FULL, data);
            do_read(1, FULL, tmp);
            $display("read data: %h", tmp);
            do_assert(data, tmp, 2);

            do_write(0, HALF, data);
            do_read(0, HALF, tmp);
            $display("read data: %h", tmp[15:0]);
            do_assert(data[15:0], tmp[15:0], 3);

            do_write(1, HALF, data);
            do_read(1, HALF, tmp);
            $display("read data: %h", tmp[15:0]);
            do_assert(data[15:0], tmp[15:0], 4);

            do_write(0, BYTE, data);
            do_read(0, BYTE, tmp);
            $display("read data: %h", tmp[7:0]);
            do_assert(data[7:0], tmp[7:0], 5);

            do_write(1, BYTE, data);
            do_read(1, BYTE, tmp);
            $display("read data: %h", tmp[7:0]);
            do_assert(data[7:0], tmp[7:0], 6);

            cpu_strobe = 0;
            #3
            @(negedge clk)

            do_write(2, BYTE, data);
            do_read(2, BYTE, tmp);
            $display("read data: %h", tmp[7:0]);
            do_assert(data[7:0], tmp[7:0], 7);

            do_write(3, BYTE, data);
            do_read(3, BYTE, tmp);
            $display("read data: %h", tmp[7:0]);
            do_assert(data[7:0], tmp[7:0], 8);

            cpu_strobe = 0;
        end

        $finish;

        
        
    end


endmodule
