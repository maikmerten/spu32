`default_nettype none

`include "./cpu/cpu.v"
`include "./bus/wishbone8.v"
`include "./ram/bram_wb8_vga.v"
`include "./leds/leds_wb8.v"

module cpu_tb();

    `include "./tb/tbcommon.v"

    reg reset = 1;
    reg interrupt = 0;

    wire cpu_strobe, cpu_write, cpu_halfword, cpu_fullword;
    wire[31:0] cpu_dat, cpu_adr;

    reg[7:0] arbiter_dat_o;
    reg arbiter_ack_o;

    reg stall = 0;
    wire ram_stall;

    wire wb_cpu_wait;
    wire[31:0] wb_cpu_data;

    spu32_cpu cpu_inst(
        .I_clk(clk),
        .I_reset(reset),
        .I_wait(wb_cpu_wait),
        .I_interrupt(interrupt),
        .I_data(wb_cpu_data),
        .O_data(cpu_dat),
        .O_addr(cpu_adr),
        .O_strobe(cpu_strobe),
        .O_write(cpu_write),
        .O_halfword(cpu_halfword),
        .O_fullword(cpu_fullword)
    );

    wire wb_ack_i, wb_cyc_o, wb_stb_o, wb_we_o;
    wire[31:0] wb_adr_o;
    wire[7:0] wb_dat_o;

    spu32_bus_wishbone8 wb8_inst(
        .I_clk(clk),
        // signals to CPU bus
        .I_strobe(cpu_strobe),
        .I_write(cpu_write),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .I_addr(cpu_adr),
        .I_data(cpu_dat),
        .O_data(wb_cpu_data),
        .O_wait(wb_cpu_wait),
        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        .ACK_I(arbiter_ack_o),
        .STALL_I(ram_stall),
        .DAT_I(arbiter_dat_o),
        .RST_I(reset),
        .ADR_O(wb_adr_o),
        .DAT_O(wb_dat_o),
        .CYC_O(wb_cyc_o),
        .STB_O(wb_stb_o),
        .WE_O(wb_we_o)
    );

    wire ram_ack;
    reg ram_stb;
    wire[7:0] ram_dat;

    bram_wb8_vga #(
        .RAMINITFILE("./software/testgen/testsuite.dat")
    ) ram_inst (
        .I_wb_clk(clk),
        .I_wb_stb(ram_stb),
        .I_wb_we(wb_we_o),
        .I_wb_adr(wb_adr_o[12:0]),
        .I_wb_dat(wb_dat_o),
        .O_wb_dat(ram_dat),
        .O_wb_ack(ram_ack),
        .O_wb_stall(ram_stall),
        .I_vga_req(stall),
        .I_vga_adr(0)
    );

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    leds_wb8 leds_inst(
        .I_wb_clk(clk),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(leds_stb),
        .I_wb_we(wb_we_o),
        .I_reset(1'b0),
        .O_wb_dat(leds_dat),
        .O_wb_ack(leds_ack),
        .O_leds(leds_value)
    );

    reg[1:0] stall_cnt = 0;
    always @(posedge clk) begin
        stall_cnt <= stall_cnt + 1;
        //stall <= 0;
        stall <= stall_cnt == 3;
        //stall <= stall_cnt[0];
        //stall <= !stall;
    end

    // bus arbiter
    always @(*) begin
        ram_stb = 0;
        leds_stb = 0;

        case(wb_adr_o[31:28])
            4'hF: begin
                arbiter_dat_o = leds_dat;
                arbiter_ack_o = leds_ack;
                leds_stb = wb_stb_o;
            end

            default: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = wb_stb_o;
            end
        endcase

    end


    initial begin
        $dumpfile("./cpu/tests/cpu_tb.lxt");
        $dumpvars(0, cpu_inst, wb8_inst);

        #3
        reset = 0;

        @(leds_value == 8'hF0)
        #128

        if(leds_value === 8'hFF) begin
            $display("VERDICT: PASS   \\o/");
        end else begin
            $display("VERDICT: !!! FAIL !!!, failed testcase %d", leds_value);
            $finish_and_return(1);
        end
        $finish;

    end

    reg[31:0] clkcount = 0;

    // make sure we don't end up in an endless loop
    always @(posedge clk) begin
        clkcount = clkcount + 1;
        if(clkcount > 99999) begin
            $display("TEST TIMED OUT!");
            $finish_and_return(1);
        end
    end


endmodule
