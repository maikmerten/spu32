`include "./boards/hx8k-breakout/config-local.vh"

`include "./cpu/cpu.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"
`include "./ram/bram_wb8.v"
`include "./ram/sram512kx8_wb8.v"
`include "./prng/prng_wb8.v"
`include "./vga/vga_wb8.v"


module top(
        input clk_12mhz,
        // UART pins on pmod header 2
        input uart_rx, uart_rts,
        output uart_tx,
        // SPI port 0
        input spi0_miso,
        output spi0_clk, spi0_mosi, spi0_cs,
        // LEDs!
        output led0, led1, led2, led3, led4, led5, led6, led7,
        // debug output stuff
        output debug1, debug2,
        // LEDs on extension board. It's harmless to drive those pins even if no extension is present.
        output eled_1, eled_2,   

        output vga_vsync, vga_hsync, vga_r, vga_g, vga_b,

        `ifdef EXTENSION_PRESENT
            // SRAM on extension board
       	    output sram_oe, sram_ce, sram_we,
            output sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17, sram_a18,
	        inout sram_d0, sram_d1, sram_d2, sram_d3, sram_d4, sram_d5, sram_d6, sram_d7
        `endif

    );

    wire clk, clk_pll, pll_locked;
    `ifdef SLOWCLK
        // Instantiate a normal PLL, 15.938 MHz
        SB_PLL40_CORE #(							
            .FEEDBACK_PATH("SIMPLE"),				
            .DIVR(4'b0000),
            .DIVF(7'b1010100),
            .DIVQ(3'b110),
            .FILTER_RANGE(3'b001)
        ) mypll (								
            .LOCK(pll_locked),					
            .RESETB(1'b1),						
            .BYPASS(1'b0),						
            .REFERENCECLK(clk_12mhz),				
            .PLLOUTCORE(clk)				
        );
        localparam CLOCKFREQ = 15938000;
    `else
        // Instantiate a normal PLL, 25.125 MHz
        SB_PLL40_CORE #(							
            .FEEDBACK_PATH("SIMPLE"),				
            .DIVR(4'b0000),
            .DIVF(7'b1000010),
            .DIVQ(3'b101),
            .FILTER_RANGE(3'b001)
        ) mypll (								
            .LOCK(pll_locked),					
            .RESETB(1'b1),						
            .BYPASS(1'b0),						
            .REFERENCECLK(clk_12mhz),				
            .PLLOUTCORE(clk)				
        );
        localparam CLOCKFREQ = 25125000;
    `endif



    reg reset = 1;
    reg[10:0] resetcnt = 1;

    wire cpu_cyc, cpu_stb, cpu_we;
    wire[7:0] cpu_dat;
    wire[31:0] cpu_adr;

    reg[7:0] arbiter_dat_o;
    reg arbiter_ack_o;

    cpu #(
        .VECTOR_RESET(32'hFFFFF000)
    ) cpu_inst(
        .CLK_I(clk),
	    .ACK_I(arbiter_ack_o),
	    .DAT_I(arbiter_dat_o),
	    .RST_I(reset),
        .INTERRUPT_I(timer_interrupt),
	    .ADR_O(cpu_adr),
	    .DAT_O(cpu_dat),
	    .CYC_O(cpu_cyc),
	    .STB_O(cpu_stb),
	    .WE_O(cpu_we)
    );

    wire rom_ack;
    reg rom_stb;
    wire[7:0] rom_dat;

    rom_wb8 #(
        .ROMINITFILE("./software/asm/bootrom.dat")
    ) rom_inst (
	    .CLK_I(clk),
	    .STB_I(rom_stb),
	    .ADR_I(cpu_adr[8:0]),
	    .DAT_I(cpu_dat),
	    .DAT_O(rom_dat),
	    .ACK_O(rom_ack)
    );

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    leds_wb8 leds_inst(
        .CLK_I(clk),
        .DAT_I(cpu_dat),
        .STB_I(leds_stb),
        .WE_I(cpu_we),
        .DAT_O(leds_dat),
        .ACK_O(leds_ack),
        .O_leds(leds_value)
    );
    assign {led0, led1, led2, led3, led4, led5, led6, led7} = leds_value;

    reg uart_stb = 0;
    wire uart_tx, uart_ack;
    wire[7:0] uart_dat;

    uart_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    ) uart_inst(
        .CLK_I(clk),
        .ADR_I(cpu_adr[1:0]),
        .DAT_I(cpu_dat),
        .STB_I(uart_stb),
        .WE_I(cpu_we),
        .DAT_O(uart_dat),
        .ACK_O(uart_ack),
        .O_tx(uart_tx),
        .I_rx(uart_rx)
    );

    assign eled_1 = !uart_rx;
    assign eled_2 = !uart_tx;

    reg spi0_stb = 0;
    wire[7:0] spi0_dat;
    wire spi0_ack;

    spi_wb8 spi0_inst(
        .CLK_I(clk),
        .ADR_I(cpu_adr[1:0]),
        .DAT_I(cpu_dat),
        .STB_I(spi0_stb),
        .WE_I(cpu_we),
        .DAT_O(spi0_dat),
        .ACK_O(spi0_ack),
        .I_spi_miso(spi0_miso),
        .O_spi_mosi(spi0_mosi),
        .O_spi_clk(spi0_clk),
        .O_spi_cs(spi0_cs)
    );

    reg timer_stb = 0;
    wire[7:0] timer_dat;
    wire timer_ack;
    wire timer_interrupt;

    timer_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    )timer_inst(
        .CLK_I(clk),
        .ADR_I(cpu_adr[2:0]),
        .DAT_I(cpu_dat),
        .STB_I(timer_stb),
        .WE_I(cpu_we),
        .DAT_O(timer_dat),
        .ACK_O(timer_ack),
        .O_interrupt(timer_interrupt)
    );

    reg prng_stb = 0;
    wire[7:0] prng_dat;
    wire prng_ack;

    prng_wb8 prng_inst(
        .CLK_I(clk),
        .ADR_I(cpu_adr[1:0]),
        .DAT_I(cpu_dat),
        .STB_I(prng_stb),
        .WE_I(cpu_we),
        .DAT_O(prng_dat),
        .ACK_O(prng_ack)
    );

    reg vga_stb = 0;
    wire[7:0] vga_dat;
    wire vga_ack;
    vga_wb8 vga_inst(
        .CLK_I(clk),
        .ADR_I(cpu_adr[12:0]),
        .DAT_I(cpu_dat),
        .STB_I(vga_stb),
        .WE_I(cpu_we),
        .DAT_O(vga_dat),
        .ACK_O(vga_ack),
        .I_vga_clk(clk),
        .O_vga_vsync(vga_vsync),
        .O_vga_hsync(vga_hsync),
        .O_vga_r(vga_r),
        .O_vga_g(vga_g),
        .O_vga_b(vga_b)
    );


    reg ram_stb;
    wire[7:0] ram_dat;
    wire ram_ack;
    `ifdef EXTENSION_PRESENT
        // if the extension board is present, use the external SRAM chip
        wire[7:0] sram_dat_to_chip;
        wire[7:0] sram_dat_from_chip;
        wire sram_output_enable;
        wire[18:0] sram_chip_adr;
        assign {sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17, sram_a18} = sram_chip_adr;

        sram512kx8_wb8 sram_inst(
            // wiring to wishbone bus
            .CLK_I(clk),
            .ADR_I(cpu_adr[18:0]),
            .DAT_I(cpu_dat),
            .STB_I(ram_stb),
            .WE_I(cpu_we),
            .DAT_O(ram_dat),
            .ACK_O(ram_ack),
            // wiring to SRAM chip
            .O_data(sram_dat_to_chip),
            .I_data(sram_dat_from_chip),
		    .O_address(sram_chip_adr),
            .O_ce(sram_ce),
            .O_oe(sram_oe),
            .O_we(sram_we),
            // output enable
            .O_output_enable(sram_output_enable)
        );

        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance0 (
            .PACKAGE_PIN(sram_d0),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[0]),
            .D_IN_0(sram_dat_from_chip[0])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance1 (
            .PACKAGE_PIN(sram_d1),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[1]),
            .D_IN_0(sram_dat_from_chip[1])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance2 (
            .PACKAGE_PIN(sram_d2),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[2]),
            .D_IN_0(sram_dat_from_chip[2])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance3 (
            .PACKAGE_PIN(sram_d3),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[3]),
            .D_IN_0(sram_dat_from_chip[3])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance4 (
            .PACKAGE_PIN(sram_d4),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[4]),
            .D_IN_0(sram_dat_from_chip[4])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance5 (
            .PACKAGE_PIN(sram_d5),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[5]),
            .D_IN_0(sram_dat_from_chip[5])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance6 (
            .PACKAGE_PIN(sram_d6),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[6]),
            .D_IN_0(sram_dat_from_chip[6])
        );
        SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance7 (
            .PACKAGE_PIN(sram_d7),
            .OUTPUT_ENABLE(sram_output_enable),
            .D_OUT_0(sram_dat_to_chip[7]),
            .D_IN_0(sram_dat_from_chip[7])
        );
    `else
        // without the extension board, generate 8KB of RAM out of BRAM ressources
        bram_wb8 #(
            .ADDRBITS(13)
        ) bram_inst(
            .CLK_I(clk),
            .ADR_I(cpu_adr[12:0]),
            .DAT_I(cpu_dat),
            .STB_I(ram_stb),
            .WE_I(cpu_we),
            .DAT_O(ram_dat),
            .ACK_O(ram_ack)
        );
    `endif


    // The iCE40 BRAMs always return zero for a while after device program and reset:
    // https://github.com/cliffordwolf/icestorm/issues/76
    // Assert reset for a while until things should have settled.
    always @(posedge clk) begin
      if(resetcnt != 0) begin
        reset <= 1;
        resetcnt <= resetcnt + 1;
      end else reset <= 0;

      // use UART rts (active low) for reset
      if(!uart_rts) begin
        resetcnt <= 1;
      end
    end

    // bus arbiter
    always @(*) begin
        leds_stb = 0;
        uart_stb = 0;
        spi0_stb = 0;
        timer_stb = 0;
        rom_stb = 0;
        ram_stb = 0;
        prng_stb = 0;
        vga_stb = 0;

        casez(cpu_adr[31:0])

            {16'hFFFF, 3'b000, {13{1'b?}}}: begin //0xFFFF0000 - 0xFFFF1FFF: VGA
                arbiter_dat_o = vga_dat;
                arbiter_ack_o = vga_ack;
                vga_stb = cpu_stb;
            end


            {20'hFFFFF, 1'b0, {11{1'b?}}}: begin // 0xFFFFF000 - 0xFFFFF7FF: boot ROM
                arbiter_dat_o = rom_dat;
                arbiter_ack_o = rom_ack;
                rom_stb = cpu_stb;
            end

            {32'hFFFFF8??}: begin // 0xFFFFF8xx: UART
                arbiter_dat_o = uart_dat;
                arbiter_ack_o = uart_ack;
                uart_stb = cpu_stb;
            end

            {32'hFFFFF9??}: begin // 0xFFFFF9xx: SPI port 0
                arbiter_dat_o = spi0_dat;
                arbiter_ack_o = spi0_ack;
                spi0_stb = cpu_stb;
            end

            // reserved:
            // 0xFFFFFAxx
            // 0xFFFFFBxx
            // 0xFFFFFCxx 

            {32'hFFFFFD??}: begin // 0xFFFFFDxx: Timer
                arbiter_dat_o = timer_dat;
                arbiter_ack_o = timer_ack;
                timer_stb = cpu_stb;
            end

            {32'hFFFFFE??}: begin // 0xFFFFFExx: predictable random number generator
                arbiter_dat_o = prng_dat;
                arbiter_ack_o = prng_ack;
                prng_stb = cpu_stb;
            end

            {32'hFFFFFF??}: begin // 0xFFFFFFxx LEDs
                arbiter_dat_o = leds_dat;
                arbiter_ack_o = leds_ack;
                leds_stb = cpu_stb;                      
            end

            default: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end

        endcase

    end


endmodule
