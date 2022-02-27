`default_nettype none

`include "./cpu/cpu.v"
`include "./bus/wishbone32.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb32.v"
`include "./ram/dummy_wb32.v"
`include "./ram/ice40_spram_1mbit_wb32_vga.v"
`include "./ram/bram_wb32.v"
`include "./rom/rom_wb32.v"
`include "./prng/prng_wb32.v"
`include "./vga/vga_wb32_extram.v"

module top(
        input clk_12mhz,
        input uart_rx, uart_rts,
        output uart_tx,
        // SPI bus
        input spi1_miso,
        output spi1_clk, spi1_mosi, spi1_flash_cs, spi1_sdcard_cs,
        // LEDs!
        output led0, led1,
        // reset button
        input reset_button,
        // VGA signals
        output vga_vsync, vga_hsync, vga_r0, vga_r1, vga_r2, vga_r3, vga_g0, vga_g1, vga_g2, vga_g3, vga_b0, vga_b1, vga_b2, vga_b3,
    );

    wire clk, pll_locked;


    reg reset = 1;
    reg[10:0] resetcnt = 1;

    wire cpu_strobe, cpu_write, cpu_halfword, cpu_fullword;
    wire[31:0] cpu_dat, cpu_adr;

    reg[31:0] arbiter_dat_o;
    reg arbiter_ack_o, arbiter_stall_o;
    wire ram_stall;

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

    reg spi_wb_stb = 0;
    wire[7:0] spi_wb_dat;
    wire spi_wb_ack;
    wire spi1_cs1, spi1_cs2, spi1_cs3;
    assign spi1_flash_cs = spi1_cs1;
    assign spi1_sdcard_cs = spi1_cs2;


    reg spram_stb;
    wire spram_ack, spram_stall;
    wire[31:0] spram_dat;

    reg timer_stb = 0;
    wire[31:0] timer_dat;
    wire timer_ack;
    wire timer_interrupt;

    reg uart_stb = 0;
    wire uart_ack;
    wire[7:0] uart_dat;

    reg vga_stb = 0;
    wire[31:0] vga_dat;
    wire[7:0] vga_r, vga_g, vga_b;
    wire[17:0] vga_ram_adr;
    wire vga_ram_req, vga_dev_vsync, vga_dev_hsync;
    wire vga_ack;
    wire[15:0] ram_vga_dat;

    assign {vga_r3, vga_r2, vga_r1, vga_r0} = vga_r[7:4];
    assign {vga_g3, vga_g2, vga_g1, vga_g0} = vga_g[7:4];
    assign {vga_b3, vga_b2, vga_b1, vga_b0} = vga_b[7:4];
    assign vga_hsync = vga_dev_hsync;
    assign vga_vsync = vga_dev_vsync;



//`define SLOWCLK
`ifdef SLOWCLK
    // 12 MHz input, 15.938 MHz output
    SB_PLL40_PAD #(
	    .FEEDBACK_PATH("SIMPLE"),
	    .DIVR(4'b0000),		// DIVR =  0
	    .DIVF(7'b1010100),	// DIVF =  84
	    .DIVQ(3'b110),		// DIVQ =  6
	    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
    ) uut (
        .LOCK(pll_locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .PACKAGEPIN(clk_12mhz),
        .PLLOUTCORE(clk)
    );
    localparam CLOCKFREQ = 15938000;

`else
    // 12 MHz input, 25.250 MHz output
    SB_PLL40_PAD #(
	    .FEEDBACK_PATH("SIMPLE"),
	    .DIVR(4'b0000),		// DIVR =  0
	    .DIVF(7'b1000010),	// DIVF =  6
	    .DIVQ(3'b101),		// DIVQ =  5
	    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
    ) uut (
        .LOCK(pll_locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .PACKAGEPIN(clk_12mhz),
        .PLLOUTCORE(clk)
    );
    localparam CLOCKFREQ = 25250000;

    // 12 MHz input, 30.000 MHz output
    /*SB_PLL40_PAD #(
	    .FEEDBACK_PATH("SIMPLE"),
	    .DIVR(4'b0000),		// DIVR =  0
	    .DIVF(7'b1001111),	// DIVF =  79
	    .DIVQ(3'b101),		// DIVQ =  5
	    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
    ) uut (
        .LOCK(pll_locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .PACKAGEPIN(clk_12mhz),
        .PLLOUTCORE(clk)
    );
    localparam CLOCKFREQ = 30000000;*/

    //12 MHz input, 30.750 MHz output
    /*SB_PLL40_PAD #(
	    .FEEDBACK_PATH("SIMPLE"),
	    .DIVR(4'b0000),		// DIVR =  0
	    .DIVF(7'b1010001),	// DIVF =  81
	    .DIVQ(3'b101),		// DIVQ =  5
	    .FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
    ) uut (
        .LOCK(pll_locked),
        .RESETB(1'b1),
        .BYPASS(1'b0),
        .PACKAGEPIN(clk_12mhz),
        .PLLOUTCORE(clk)
    );
    localparam CLOCKFREQ = 30750000;*/
    
`endif



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
        .ROMINITFILE("./software/asm/bootrom.dat32")
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
    assign {led0, led1} = {!leds_value[0], !leds_value[1]};
    

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


    spi_wb8 spi_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_dat(wb_dat_o[7:0]),
        .I_wb_stb(spi_wb_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(spi_wb_dat),
        .O_wb_ack(spi_wb_ack),
        .I_spi_miso(spi1_miso),
        .O_spi_mosi(spi1_mosi),
        .O_spi_clk(spi1_clk),
        .O_spi_cs1(spi1_cs1),
        .O_spi_cs2(spi1_cs2),
        .O_spi_cs3(spi1_cs3)
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


`define SPRAM 1
`ifdef SPRAM
    ice40_spram_1mbit_wb32_vga spram_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[14:0]),
        .I_wb_sel(wb_sel_o),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(spram_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(spram_dat),
        .O_wb_ack(spram_ack),
        .O_wb_stall(spram_stall),
        .I_vga_req(vga_ram_req),
        .I_vga_adr(vga_ram_adr[15:0]),
        .O_vga_dat(ram_vga_dat),
    );
`else
    bram_wb32
	#(
		.ADDRBITS(11), // by default, 8 KB of BRAM
		.RAMINITFILE("./ram/raminit.dat")
	)  bram32_inst
	(
		.I_wb_clk(clk),
		.I_wb_stb(spram_stb),
		.I_wb_we(wb_we_o),
	    .I_wb_adr(wb_adr_o[10:0]),
		.I_wb_dat(wb_dat_o),
        .I_wb_sel(wb_sel_o),
		.O_wb_dat(spram_dat),
		.O_wb_ack(spram_ack)
	);
`endif

    vga_wb32_extram vga_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_sel(wb_sel_o),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(vga_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(vga_dat),
        .O_wb_ack(vga_ack),
        .I_reset(reset),
        .O_ram_req(vga_ram_req),
        .O_ram_adr(vga_ram_adr),
        .I_ram_dat(ram_vga_dat),
        .I_vga_clk(clk),
        .O_vga_vsync(vga_dev_vsync),
        .O_vga_hsync(vga_dev_hsync),
        .O_vga_r(vga_r),
        .O_vga_g(vga_g),
        .O_vga_b(vga_b)
    );



    wire uart_reset_blocked = 1'b0; //(leds_value == 8'hFF);

    // The iCE40 BRAMs always return zero for a while after device program and reset:
    // https://github.com/cliffordwolf/icestorm/issues/76
    // Assert reset for a while until things should have settled.
    always @(posedge clk) begin
      if(resetcnt != 0) begin
        reset <= 1;
        resetcnt <= resetcnt + 1;
      end else reset <= 0;

      // use UART rts (active low) for reset
      // evil hack: ignore UART rts if all LEDs are set
      //if(((!uart_rts) && (!uart_reset_blocked)) || !reset_button) begin
      // resetcnt <= 1;
      //end
      if(!reset_button) begin
          resetcnt <= 1;
      end
    end

    // wishbone bus arbiter
    always @(*) begin
        leds_stb = 0;
        uart_stb = 0;
        spi_wb_stb = 0;
        timer_stb = 0;
        dummy_stb = 0;
        rom_stb = 0;
        prng_stb = 0;
        spram_stb = 0;
        vga_stb = 0;
        arbiter_stall_o = 0;

        casez({wb_adr_o[29:0], 2'b00})

            {16'hFFFF, 3'b000, {13{1'b?}}}: begin //0xFFFF0000 - 0xFFFF1FFF: VGA
                arbiter_dat_o = vga_dat;
                arbiter_ack_o = vga_ack;
                vga_stb = wb_stb_o;
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

            {32'hFFFFF9??}: begin // 0xFFFFF9xx: SPI port
                arbiter_dat_o = {24'h000000, spi_wb_dat};
                arbiter_ack_o = spi_wb_ack;
                spi_wb_stb = wb_stb_o;
            end

            // reserved:
            // 0xFFFFFAxx
            // 0xFFFFFBxx
            {32'hFFFFFC??}: begin // 0xFFFFFCxx: IR receiver
                // dummy device, IR receiver not implemented yet
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
                arbiter_dat_o = spram_dat;
                arbiter_ack_o = spram_ack;
                arbiter_stall_o = spram_stall;
                spram_stb = wb_stb_o;
            end

        endcase

    end


endmodule
