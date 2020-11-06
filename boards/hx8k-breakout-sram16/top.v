`default_nettype none

`include "./cpu/cpu.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"
`include "./ram/sram256kx16_wb8_vga_ice40.v"
`include "./ram/bram_wb8.v"
`include "./prng/prng_wb8.v"
`include "./vga/vga_wb8_extram.v"
`include "./irdecoder/irdecoder_wb8.v"
`include "./audio/sn76489_wb8.v"


module top(
        input clk_12mhz,
        input uart_rx, uart_rts,
        output uart_tx,
        // SPI device 1
        input spi1_miso,
        output spi1_clk, spi1_mosi, spi1_cs1, spi1_cs2, spi1_cs3,
        // LEDs!
        output led0, led1, led2, led3, led4, led5, led6, led7,
        // debug output stuff
        output debug1, debug2,
        // LEDs on extension board. It's harmless to drive those pins even if no extension is present.
        output eled_1, eled_2, 
        // reset button
        input reset_button,
        // infrared receiver
        input ir_receiver,
        // audio output
        output audio_out0,

        output vga_vsync, vga_hsync, vga_r0, vga_r1, vga_r2, vga_r3, vga_g0, vga_g1, vga_g2, vga_g3, vga_b0, vga_b1, vga_b2, vga_b3,

        // SRAM on extension board
        output sram_oe, sram_ce, sram_we, sram_lb, sram_ub,
        output sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17,
        inout sram_d0, sram_d1, sram_d2, sram_d3, sram_d4, sram_d5, sram_d6, sram_d7, sram_d8, sram_d9, sram_d10, sram_d11, sram_d12, sram_d13, sram_d14, sram_d15

    );

    wire clk, clk_pll, pll_locked;
    // Instantiate PLL, 25.125 MHz
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



    reg reset = 1;
    reg[10:0] resetcnt = 1;

    wire cpu_cyc, cpu_stb, cpu_we;
    wire[7:0] cpu_dat;
    wire[31:0] cpu_adr;

    reg[7:0] arbiter_dat_o;
    reg arbiter_ack_o;
    wire ram_stall;

    spu32_cpu #(
        .VECTOR_RESET(32'hFFFFF000)
    ) cpu_inst(
        .CLK_I(clk),
	    .ACK_I(arbiter_ack_o),
        .STALL_I(ram_stall),
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
	    .I_wb_clk(clk),
	    .I_wb_stb(rom_stb),
	    .I_wb_adr(cpu_adr[8:0]),
	    .O_wb_dat(rom_dat),
	    .O_wb_ack(rom_ack)
    );

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    leds_wb8 leds_inst(
        .I_wb_clk(clk),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(leds_stb),
        .I_wb_we(cpu_we),
        .I_reset(reset),
        .O_wb_dat(leds_dat),
        .O_wb_ack(leds_ack),
        .O_leds(leds_value)
    );
    assign {led0, led1, led2, led3, led4, led5, led6, led7} = leds_value;

    reg uart_stb = 0;
    wire uart_ack;
    wire[7:0] uart_dat;

    uart_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    ) uart_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[1:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(uart_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(uart_dat),
        .O_wb_ack(uart_ack),
        .O_tx(uart_tx),
        .I_rx(uart_rx)
    );

    assign eled_1 = !uart_rx;
    assign eled_2 = !uart_tx;

    reg spi_wb_stb = 0;
    wire[7:0] spi_wb_dat;
    wire spi_wb_ack;


    spi_wb8 spi_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[1:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(spi_wb_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(spi_wb_dat),
        .O_wb_ack(spi_wb_ack),
        .I_spi_miso(spi1_miso),
        .O_spi_mosi(spi1_mosi),
        .O_spi_clk(spi1_clk),
        .O_spi_cs1(spi1_cs1),
        .O_spi_cs2(spi1_cs2),
        .O_spi_cs3(spi1_cs3)
    );

    reg timer_stb = 0;
    wire[7:0] timer_dat;
    wire timer_ack;
    wire timer_interrupt;

    timer_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    )timer_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[2:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(timer_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(timer_dat),
        .O_wb_ack(timer_ack),
        .O_interrupt(timer_interrupt)
    );

    reg prng_stb = 0;
    wire[7:0] prng_dat;
    wire prng_ack;

    prng_wb8 prng_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[1:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(prng_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(prng_dat),
        .O_wb_ack(prng_ack)
    );

    wire[7:0] ram_dat;



    reg vga_stb = 0;
    wire[7:0] vga_dat;
    wire[7:0] vga_r, vga_g, vga_b;
    wire[17:0] vga_ram_adr;
    wire vga_ram_req;
    wire vga_ack;
    wire[15:0] ram_vga_dat;


    vga_wb8_extram vga_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[12:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(vga_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(vga_dat),
        .O_wb_ack(vga_ack),
        .I_reset(reset),
        .O_ram_req(vga_ram_req),
        .O_ram_adr(vga_ram_adr),
        .I_ram_dat(ram_vga_dat),
        .I_vga_clk(clk),
        .O_vga_vsync(vga_vsync),
        .O_vga_hsync(vga_hsync),
        .O_vga_r(vga_r),
        .O_vga_g(vga_g),
        .O_vga_b(vga_b)
    );

    assign {vga_r3, vga_r2, vga_r1, vga_r0} = vga_r[7:4];
    assign {vga_g3, vga_g2, vga_g1, vga_g0} = vga_g[7:4];
    assign {vga_b3, vga_b2, vga_b1, vga_b0} = vga_b[7:4];


    reg irdecoder_stb = 0;
    wire[7:0] irdecoder_dat;
    wire irdecoder_ack;
    irdecoder_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    ) irdecoder_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[2:0]),
        .I_wb_stb(irdecoder_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(irdecoder_dat),
        .O_wb_ack(irdecoder_ack),
        .I_ir_signal(ir_receiver)
    );

    reg audio_stb = 0;
    wire[7:0] audio_dat;
    wire audio_ack;
    sn76489_wb8 sn76489_inst(
        .I_wb_clk(clk),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(audio_stb),
        .I_wb_we(cpu_we),
        .O_wb_ack(audio_ack),
        .O_wb_dat(audio_dat),
        .I_reset(reset),
        .O_audio_modulated(audio_out0)
    );


//`define BRAM 1
    reg ram_stb;
    wire ram_ack;

    wire[17:0] sram_chip_adr;
    assign {sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17} = sram_chip_adr;
    wire[15:0] sram_chip_dat = {sram_d15, sram_d14, sram_d13, sram_d12, sram_d11, sram_d10, sram_d9, sram_d8, sram_d7, sram_d6, sram_d5, sram_d4, sram_d3, sram_d2, sram_d1, sram_d0};

    sram256kx16_wb8_vga_ice40 sram_inst(
        // wiring to wishbone bus
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[18:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(ram_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(ram_dat),
        .O_wb_ack(ram_ack),
        .O_wb_stall(ram_stall),
        // VGA read port
        .I_vga_req(vga_ram_req),
        .I_vga_adr(vga_ram_adr[17:0]),
        .O_vga_dat(ram_vga_dat),
        // wiring to SRAM chip
        .IO_data(sram_chip_dat),
		.O_address(sram_chip_adr),
        .O_ce(sram_ce),
        .O_oe(sram_oe),
        .O_we(sram_we),
        .O_lb(sram_lb),
        .O_ub(sram_ub),
    );


`ifdef BRAM
    reg bram_stb;
    wire bram_ack;
    wire[7:0] bram_dat;

    bram_wb8 #(
        .ADDRBITS(13)
    ) bram_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[12:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(bram_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(bram_dat),
        .O_wb_ack(bram_ack)
    );
`endif

    wire uart_reset_blocked = (leds_value == 8'hFF);

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
      if(((!uart_rts) && (!uart_reset_blocked)) || !reset_button) begin
        resetcnt <= 1;
      end
    end

    // bus arbiter
    always @(*) begin
        leds_stb = 0;
        uart_stb = 0;
        spi_wb_stb = 0;
        timer_stb = 0;
        rom_stb = 0;
        ram_stb = 0;
        prng_stb = 0;
        irdecoder_stb = 0;
        audio_stb = 0;
        vga_stb = 0;
    `ifdef BRAM
        bram_stb = 0;
    `endif

        casez(cpu_adr[31:0])

`ifdef BRAM
            {32'h01??????}: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end
`endif

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

            {32'hFFFFF9??}: begin // 0xFFFFF9xx: SPI port
                arbiter_dat_o = spi_wb_dat;
                arbiter_ack_o = spi_wb_ack;
                spi_wb_stb = cpu_stb;
            end

            // reserved:
            // 0xFFFFFAxx
            // 0xFFFFFBxx
            
            {32'hFFFFFC??}: begin // 0xFFFFFCxx: IR receiver
                arbiter_dat_o = irdecoder_dat;
                arbiter_ack_o = irdecoder_ack;
                irdecoder_stb = cpu_stb;
            end

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

            {32'hFFFFFF0?}: begin // 0xFFFFFF0x: audio
                arbiter_dat_o = audio_dat;
                arbiter_ack_o = audio_ack;
                audio_stb = cpu_stb;
            end

            // reserved:
            // 0xFFFFFF1x to 0xFFFFFFEx

            {32'hFFFFFFF?}: begin // 0xFFFFFFFx LEDs
                arbiter_dat_o = leds_dat;
                arbiter_ack_o = leds_ack;
                leds_stb = cpu_stb;                      
            end

            default: begin
`ifdef BRAM
                arbiter_dat_o = bram_dat;
                arbiter_ack_o = bram_ack;
                bram_stb = cpu_stb;
`else
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
`endif
            end

        endcase

    end


endmodule
