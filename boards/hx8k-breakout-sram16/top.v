`default_nettype none

`include "./cpu/cpu.v"
`include "./bus/wishbone8.v"
`include "./bus/memory16.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"
`include "./ram/sram256kx16_membus_vga_ice40.v"
`include "./ram/sram256kx16_wb8_vga_ice40.v"
`include "./ram/bram_wb8.v"
`include "./prng/prng_wb8.v"
`include "./vga/vga_wb8_extram.v"
`include "./vga/vga_dither.v"
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

    wire clk_multiplied, clk, clk_90deg, pll_locked;
    // multiply incoming 12 MHz clock to 100.5 MHz
    SB_PLL40_CORE #(							
        .FEEDBACK_PATH("SIMPLE"),				
        .DIVR(4'b0000),
        .DIVF(7'b1000010),
        .DIVQ(3'b011),
        .FILTER_RANGE(3'b001)
    ) mypll1 (								
        .RESETB(1'b1),						
        .BYPASS(1'b0),						
        .REFERENCECLK(clk_12mhz),				
        .PLLOUTCORE(clk_multiplied)				
    );

    // scale 100.5 MHz down to 25.125 MHz, also generate clock with 90 degree phase offset
    SB_PLL40_2F_CORE #(							
        .DIVR(4'b0011),
        .DIVF(7'b0000000),
        .DIVQ(3'b101),
        .FILTER_RANGE(3'b001),
        .FEEDBACK_PATH("PHASE_AND_DELAY"),
        .DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
        .FDA_FEEDBACK(4'b0000),
        .DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
        .FDA_RELATIVE(4'b0000),
        .SHIFTREG_DIV_MODE(2'b00),
        .PLLOUT_SELECT_PORTA("SHIFTREG_0deg"),
        .PLLOUT_SELECT_PORTB("SHIFTREG_90deg"),
        .ENABLE_ICEGATE_PORTA(1'b0),
        .ENABLE_ICEGATE_PORTB(1'b0)
    ) mypll2 (								
        .LOCK(pll_locked),					
        .RESETB(1'b1),						
        .BYPASS(1'b0),						
        .REFERENCECLK(clk_multiplied),				
        .PLLOUTGLOBALA(clk),
        .PLLOUTGLOBALB(clk_90deg)
    );


    localparam CLOCKFREQ = 25125000;



    reg reset = 1;
    reg[10:0] resetcnt = 1;

    wire cpu_strobe, cpu_write, cpu_halfword, cpu_fullword;
    wire[31:0] cpu_dat, cpu_adr;

    reg[7:0] arbiter_dat_o;
    reg arbiter_ack_o, arbiter_stall_o;
    wire ram_stall;

//`define FASTMEM

    wire wb_cpu_wait;
    wire[31:0] wb_cpu_data;

`ifdef FASTMEM
    wire membus_cpu_wait;
    wire[31:0] membus_cpu_data;

    wire membus_selected = (cpu_adr[31] == 1'b0);
    wire wb_selected = !membus_selected;

    reg dataselect_wb;
    always @(posedge clk) begin
        // the CPU changes address on negative clock edges, but puts data into
        // registers on positive clock edges. Thus keep incoming data for the CPU
        // stable for a bit so that data is read from correct bus system.
        dataselect_wb <= wb_selected;
    end

    wire bus_cpu_wait = wb_selected ? wb_cpu_wait : membus_cpu_wait;
    wire[31:0] bus_cpu_data = dataselect_wb ? wb_cpu_data : membus_cpu_data;
`else
    wire wb_selected = 1'b1;
    wire bus_cpu_wait = wb_cpu_wait;
    wire[31:0] bus_cpu_data = wb_cpu_data;
`endif

    spu32_cpu #(
        .VECTOR_RESET(32'hFFFFF000)
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

    wire wb_ack_i, wb_cyc_o, wb_stb_o, wb_we_o;
    wire[31:0] wb_adr_o;
    wire[7:0] wb_dat_o;

    spu32_bus_wishbone8 wb8_inst(
        .I_clk(clk),
        // signals to CPU bus
        .I_strobe(cpu_strobe & wb_selected),
        .I_write(cpu_write & wb_selected),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .I_addr(cpu_adr),
        .I_data(cpu_dat),
        .O_data(wb_cpu_data),
        .O_wait(wb_cpu_wait),
        // wired to outside world, RAM, devices etc.
        //naming of signals taken from Wishbone B4 spec
        .ACK_I(arbiter_ack_o),
        .STALL_I(arbiter_stall_o),
        .DAT_I(arbiter_dat_o),
        .RST_I(reset),
        .ADR_O(wb_adr_o),
        .DAT_O(wb_dat_o),
        .CYC_O(wb_cyc_o),
        .STB_O(wb_stb_o),
        .WE_O(wb_we_o)
    );

`ifdef FASTMEM
    wire[15:0] membus_sram_data;
    wire[17:0] membus_sram_addr;
    wire[3:0] membus_sram_request;
    wire membus_sram_we, membus_sram_ub, membus_sram_lb;

    spu32_bus_memory16 bus_memory_inst
    (
        .I_clk(clk),
        // signals to/from CPU
        .I_data(cpu_dat),
        .I_addr(cpu_adr),
        .I_strobe(cpu_strobe & membus_selected),
        .I_write(cpu_write & membus_selected),
        .I_halfword(cpu_halfword),
        .I_fullword(cpu_fullword),
        .O_data(membus_cpu_data),
        .O_wait(membus_cpu_wait),
        // signals to/from SRAM
        .I_sram_ack(sram_membus_ack),
        .I_sram_stall(sram_membus_stall),
        .I_sram_data(sram_membus_data),
        .O_sram_data(membus_sram_data),
        .O_sram_addr(membus_sram_addr),
        .O_sram_request(membus_sram_request),
        .O_sram_we(membus_sram_we),
        .O_sram_ub(membus_sram_ub),
        .O_sram_lb(membus_sram_lb)
    );
`endif

    wire rom_ack;
    reg rom_stb;
    wire[7:0] rom_dat;

    rom_wb8 #(
        .ROMINITFILE("./software/asm/bootrom.dat")
    ) rom_inst (
	    .I_wb_clk(clk),
	    .I_wb_stb(rom_stb),
	    .I_wb_adr(wb_adr_o[8:0]),
	    .O_wb_dat(rom_dat),
	    .O_wb_ack(rom_ack)
    );

    reg leds_stb;
    wire[7:0] leds_value, leds_dat;
    wire leds_ack;

    leds_wb8 leds_inst(
        .I_wb_clk(clk),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(leds_stb),
        .I_wb_we(wb_we_o),
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
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(uart_stb),
        .I_wb_we(wb_we_o),
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
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_dat(wb_dat_o),
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

    reg timer_stb = 0;
    wire[7:0] timer_dat;
    wire timer_ack;
    wire timer_interrupt;

    timer_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    )timer_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[2:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(timer_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(timer_dat),
        .O_wb_ack(timer_ack),
        .O_interrupt(timer_interrupt)
    );

    reg prng_stb = 0;
    wire[7:0] prng_dat;
    wire prng_ack;

    prng_wb8 prng_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[1:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(prng_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(prng_dat),
        .O_wb_ack(prng_ack)
    );


    reg vga_stb = 0;
    wire[7:0] vga_dat;
    wire[7:0] vga_r, vga_g, vga_b;
    wire[17:0] vga_ram_adr;
    wire vga_ram_req, vga_dev_vsync, vga_dev_hsync;
    wire vga_ack;
    wire[15:0] ram_vga_dat;


    vga_wb8_extram vga_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[12:0]),
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

    wire[11:0] vga_dither_rgb;
    vga_dither_24_to_12 vga_dither_inst(
        .I_clk(clk),
        .I_vsync(vga_dev_vsync),
        .I_hsync(vga_dev_hsync),
        .I_rgb24({vga_r, vga_g, vga_b}),
        .O_vsync(vga_vsync),
        .O_hsync(vga_hsync),
        .O_rgb12(vga_dither_rgb)
    );


    assign {vga_r3, vga_r2, vga_r1, vga_r0} = vga_dither_rgb[11:8];
    assign {vga_g3, vga_g2, vga_g1, vga_g0} = vga_dither_rgb[7:4];
    assign {vga_b3, vga_b2, vga_b1, vga_b0} = vga_dither_rgb[3:0];


    reg irdecoder_stb = 0;
    wire[7:0] irdecoder_dat;
    wire irdecoder_ack;
    irdecoder_wb8 #(
        .CLOCKFREQ(CLOCKFREQ)
    ) irdecoder_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[2:0]),
        .I_wb_stb(irdecoder_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(irdecoder_dat),
        .O_wb_ack(irdecoder_ack),
        .I_ir_signal(ir_receiver)
    );

    reg audio_stb = 0;
    wire[7:0] audio_dat;
    wire audio_ack;
    sn76489_wb8 sn76489_inst(
        .I_wb_clk(clk),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(audio_stb),
        .I_wb_we(wb_we_o),
        .O_wb_ack(audio_ack),
        .O_wb_dat(audio_dat),
        .I_reset(reset),
        .O_audio_modulated(audio_out0)
    );


//`define BRAM 1

    wire[17:0] sram_chip_adr;
    assign {sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17} = sram_chip_adr;
    wire[15:0] sram_chip_dat = {sram_d15, sram_d14, sram_d13, sram_d12, sram_d11, sram_d10, sram_d9, sram_d8, sram_d7, sram_d6, sram_d5, sram_d4, sram_d3, sram_d2, sram_d1, sram_d0};

`ifdef FASTMEM
    wire[3:0] sram_membus_ack;
    wire[15:0] sram_membus_data;
    wire sram_membus_stall;

    sram256kx16_membus_vga_ice40 sram_inst(
        // wiring to "fast-path" membus
        .I_clk(clk),
        .I_clk_90deg(clk_90deg),
        .I_request(membus_sram_request),
        .I_we(membus_sram_we),
        .I_ub(membus_sram_ub),
        .I_lb(membus_sram_lb),
        .I_addr(membus_sram_addr),
        .I_data(membus_sram_data),
        .O_data(sram_membus_data),
        .O_ack(sram_membus_ack),
        .O_stall(sram_membus_stall),
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
`else
    reg ram_stb;
    wire ram_ack;
    wire[7:0] ram_dat;

    sram256kx16_wb8_vga_ice40 sram_inst(
        // wiring to wishbone bus
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[18:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(ram_stb),
        .I_wb_we(wb_we_o),
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
`endif


`ifdef BRAM
    reg bram_stb;
    wire bram_ack;
    wire[7:0] bram_dat;

    bram_wb8 #(
        .ADDRBITS(13)
    ) bram_inst(
        .I_wb_clk(clk),
        .I_wb_adr(wb_adr_o[12:0]),
        .I_wb_dat(wb_dat_o),
        .I_wb_stb(bram_stb),
        .I_wb_we(wb_we_o),
        .O_wb_dat(bram_dat),
        .O_wb_ack(bram_ack)
    );
`endif

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
      if(((!uart_rts) && (!uart_reset_blocked)) || !reset_button) begin
        resetcnt <= 1;
      end
    end

    // wishbone bus arbiter
    always @(*) begin
        leds_stb = 0;
        uart_stb = 0;
        spi_wb_stb = 0;
        timer_stb = 0;
        rom_stb = 0;
        prng_stb = 0;
        irdecoder_stb = 0;
        audio_stb = 0;
        vga_stb = 0;
    `ifdef BRAM
        bram_stb = 0;
    `endif
    `ifndef FASTMEM
        ram_stb = 0;
    `endif

        arbiter_stall_o = 0;

        casez(wb_adr_o[31:0])

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
                arbiter_dat_o = uart_dat;
                arbiter_ack_o = uart_ack;
                uart_stb = wb_stb_o;
            end

            {32'hFFFFF9??}: begin // 0xFFFFF9xx: SPI port
                arbiter_dat_o = spi_wb_dat;
                arbiter_ack_o = spi_wb_ack;
                spi_wb_stb = wb_stb_o;
            end

            // reserved:
            // 0xFFFFFAxx
            // 0xFFFFFBxx
            
            {32'hFFFFFC??}: begin // 0xFFFFFCxx: IR receiver
                arbiter_dat_o = irdecoder_dat;
                arbiter_ack_o = irdecoder_ack;
                irdecoder_stb = wb_stb_o;
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

            {32'hFFFFFF0?}: begin // 0xFFFFFF0x: audio
                arbiter_dat_o = audio_dat;
                arbiter_ack_o = audio_ack;
                audio_stb = wb_stb_o;
            end

            // reserved:
            // 0xFFFFFF1x to 0xFFFFFFEx

            {32'hFFFFFFF?}: begin // 0xFFFFFFFx LEDs
                arbiter_dat_o = leds_dat;
                arbiter_ack_o = leds_ack;
                leds_stb = wb_stb_o;                      
            end

            default: begin
`ifdef BRAM
                arbiter_dat_o = bram_dat;
                arbiter_ack_o = bram_ack;
                bram_stb = wb_stb_o;
`else
    `ifdef FASTMEM
                arbiter_dat_o = 8'h00;
                arbiter_ack_o = 1'b1;
    `else
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                arbiter_stall_o = ram_stall;
                ram_stb = wb_stb_o;
    `endif
`endif
            end

        endcase

    end


endmodule
