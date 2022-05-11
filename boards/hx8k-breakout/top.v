`default_nettype none

`include "./cpu/cpu.v"
`include "./bus/wishbone32.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./timer/timer_wb32.v"
`include "./ram/dummy_wb32.v"
`include "./ram/bram_wb32.v"
`include "./rom/rom_wb32.v"
`include "./prng/prng_wb32.v"

module top(
        input clk_12mhz,
        input uart_rx, uart_rts,
        output uart_tx,
        // LEDs!
        output led0, led1, led2, led3, led4, led5, led6, led7,
    );

    wire clk, pll_locked;


    reg reset = 1;
    reg[10:0] resetcnt = 1;

    wire cpu_strobe, cpu_write, cpu_halfword, cpu_fullword;
    wire[31:0] cpu_dat, cpu_adr;

    reg[31:0] arbiter_dat_o;
    reg arbiter_ack_o, arbiter_stall_o;

    wire wb_cpu_wait;
    wire[31:0] wb_cpu_data;

    wire wb_selected = 1'b1;
    wire bus_cpu_wait = wb_cpu_wait;
    wire[31:0] bus_cpu_data = wb_cpu_data;

    wire wb_ack_i, wb_cyc_o, wb_stb_o, wb_we_o;
    wire[29:0] wb_adr_o;
    wire[3:0] wb_sel_o;
    wire[31:0] wb_dat_o;

    reg dummy_stb;
    wire[31:0] dummy_dat;
    wire dummy_ack;

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    reg prng_stb = 0;
    wire[31:0] prng_dat;
    wire prng_ack;

    wire rom_ack;
    reg rom_stb;
    wire[31:0] rom_dat;

    reg bram_stb;
    wire bram_ack;
    wire[31:0] bram_dat;

    reg timer_stb = 0;
    wire[31:0] timer_dat;
    wire timer_ack;
    wire timer_interrupt;

    reg uart_stb = 0;
    wire uart_ack;
    wire[7:0] uart_dat;


    wire clk, pll_locked;
    SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b1000010),	// DIVF = 66
		.DIVQ(3'b101),		// DIVQ =  5
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(pll_locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clk_12mhz),
		.PLLOUTCORE(clk)
    );


    localparam CLOCKFREQ = 25125000;
    

    spu32_cpu #(
        .VECTOR_RESET(32'hFFFFF000),
        .ALU_MULDSP(0) // single-cycle DSP multiplication (disabled for now, due to speed path)
    ) cpu_inst(
        .I_clk(clk),
        .I_reset(reset),
        .I_wait(bus_cpu_wait),
        .I_interrupt(timer_interrupt),
        .I_data(bus_cpu_data),
        .O_data(cpu_dat),
        .O_addr(cpu_adr),
        .O_strobe(cpu_strobe),
        .O_write(cpu_write),
        .O_halfword(cpu_halfword),
        .O_fullword(cpu_fullword)
    );


    spu32_bus_wishbone32 wb32_inst(
        .I_clk(clk),
        // signals to CPU bus
        .I_strobe(cpu_strobe & wb_selected),
        .I_write(cpu_write & wb_selected),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .I_addr(cpu_adr),
        .I_data(cpu_dat),
        .I_reset(reset),
        .O_data(wb_cpu_data),
        .O_wait(wb_cpu_wait),
        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        .I_wb_ack(arbiter_ack_o),
        .I_wb_stall(arbiter_stall_o),
        .I_wb_dat(arbiter_dat_o),
        .O_wb_adr(wb_adr_o),
        .O_wb_sel(wb_sel_o),
        .O_wb_dat(wb_dat_o),
        .O_wb_cyc(wb_cyc_o),
        .O_wb_stb(wb_stb_o),
        .O_wb_we(wb_we_o)
    );


    dummy_wb32 dummy_inst(
        .I_wb_clk(clk),
        .I_wb_stb(dummy_stb),
        .O_wb_dat(dummy_dat),
        .O_wb_ack(dummy_ack)
    );

    rom_wb32 #(
        .ROMINITFILE("./software/asm/bootrom_onlyuart.dat32")
        //.ROMINITFILE("./software/asm/blink-test.dat32")
        //.ROMINITFILE("./software/asm/uart-echo.dat32")
    ) rom_inst (
	    .I_wb_clk(clk),
	    .I_wb_stb(rom_stb),
	    .I_wb_adr(wb_adr_o[7:0]),
	    .O_wb_dat(rom_dat),
	    .O_wb_ack(rom_ack)
    );



    leds_wb8 leds_inst(
        .I_wb_clk(clk),
        .I_wb_dat(wb_dat_o[7:0]),
        .I_wb_stb(leds_stb),
        .I_wb_we(wb_we_o),
        .I_reset(reset),
        .O_wb_dat(leds_dat),
        .O_wb_ack(leds_ack),
        .O_leds(leds_value)
    );
    assign {led0, led1, led2, led3, led4, led5, led6, led7} = leds_value;
    

    uart_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    ) uart_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_dat(wb_dat_o[7:0]),
        .I_wb_stb(uart_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(uart_dat),
        .O_wb_ack(uart_ack),
        .O_tx(uart_tx),
        .I_rx(uart_rx)
    );


    timer_wb32 #(
        .CLOCKFREQ(CLOCKFREQ)
    )timer_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[0]),
        .I_wb_sel(wb_sel_o),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(timer_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(timer_dat),
        .O_wb_ack(timer_ack),
        .O_interrupt(timer_interrupt)
    );


    prng_wb32 prng_inst(
        .I_wb_clk(clk),
        .I_wb_sel(wb_sel_o),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(prng_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(prng_dat),
        .O_wb_ack(prng_ack)
    );

    bram_wb32
	#(
		.ADDRBITS(11), // by default, 8 KB of BRAM
		.RAMINITFILE("./ram/raminit.dat")
	)  bram32_inst
	(
		.I_wb_clk(clk),
		.I_wb_stb(bram_stb),
		.I_wb_we(wb_we_o),
	    .I_wb_adr(wb_adr_o[10:0]),
		.I_wb_dat(wb_dat_o),
        .I_wb_sel(wb_sel_o),
		.O_wb_dat(bram_dat),
		.O_wb_ack(bram_ack)
	);


    // The iCE40 BRAMs always return zero for a while after device program and reset:
    // https://github.com/cliffordwolf/icestorm/issues/76
    // Assert reset for a while until things should have settled.
    always @(posedge clk) begin
      if(resetcnt != 0) begin
        reset <= 1;
        resetcnt <= resetcnt + 1;
      end else reset <= 0;

      if(!uart_rts) begin
          resetcnt <= 1;
      end
    end

    // wishbone bus arbiter
    always @(*) begin
        leds_stb = 0;
        uart_stb = 0;
        timer_stb = 0;
        dummy_stb = 0;
        rom_stb = 0;
        prng_stb = 0;
        bram_stb = 0;
        arbiter_stall_o = 0;

        casez({wb_adr_o[29:0], 2'b00})

            {16'hFFFF, 3'b000, {13{1'b?}}}: begin //0xFFFF0000 - 0xFFFF1FFF: reserved for VGA
                arbiter_dat_o = dummy_dat;
                arbiter_ack_o = dummy_ack;
                dummy_stb = wb_stb_o;
            end

            {20'hFFFFF, 1'b0, {11{1'b?}}}: begin // 0xFFFFF000 - 0xFFFFF7FF: boot ROM
                arbiter_dat_o = rom_dat;
                arbiter_ack_o = rom_ack;
                rom_stb = wb_stb_o;
            end

            {32'hFFFFF8??}: begin // 0xFFFFF8xx: UART
                arbiter_dat_o = {24'h000000, uart_dat};
                arbiter_ack_o = uart_ack;
                uart_stb = wb_stb_o;
            end

            {32'hFFFFF9??}: begin // 0xFFFFF9xx: reserved for SPI port
                arbiter_dat_o = dummy_dat;
                arbiter_ack_o = dummy_ack;
                dummy_stb = wb_stb_o;
            end

            // reserved:
            // 0xFFFFFAxx
            // 0xFFFFFBxx
            {32'hFFFFFC??}: begin // 0xFFFFFCxx: reserved for IR receiver
                arbiter_dat_o = dummy_dat;
                arbiter_ack_o = dummy_ack;
                dummy_stb = wb_stb_o;    
            end


            {32'hFFFFFD??}: begin // 0xFFFFFDxx: Timer
                arbiter_dat_o = timer_dat;
                arbiter_ack_o = timer_ack;
                timer_stb = wb_stb_o;
            end

            {32'hFFFFFE??}: begin // 0xFFFFFExx: predictable random number generator
                arbiter_dat_o = prng_dat;
                arbiter_ack_o = prng_ack;
                prng_stb = wb_stb_o;
            end


            // reserved:
            // 0xFFFFFF1x to 0xFFFFFFEx

            {32'hFFFFFFF?}: begin // 0xFFFFFFFx LEDs
                arbiter_dat_o = {4{leds_dat}};
                arbiter_ack_o = leds_ack;
                leds_stb = wb_stb_o;                      
            end


            default: begin
                arbiter_dat_o = bram_dat;
                arbiter_ack_o = bram_ack;
                bram_stb = wb_stb_o;
            end

        endcase

    end


endmodule
