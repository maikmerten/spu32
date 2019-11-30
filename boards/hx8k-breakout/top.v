`include "./boards/hx8k-breakout/config-local.vh"

`include "./cpu/cpu.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"
`include "./ram/bram_wb8.v"
`include "./ram/sram512kx8_wb8_vga.v"
`include "./prng/prng_wb8.v"
`include "./vga/vga_wb8_extram.v"
`include "./irdecoder/irdecoder_wb8.v"
`include "./audio/sn76489_wb8.v"


module top(
        input clk_12mhz,
        // UART pins on pmod header 2
        input uart_rx, uart_rts,
        output uart_tx,
        // SPI device 1
        input spi1_miso,
        output spi1_clk, spi1_mosi, spi1_cs,
        // SPI device 2
        input spi2_miso,
        output spi2_clk, spi2_mosi, spi2_cs,
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

    wire spi_mosi, spi_miso, spi_clk, spi_cs1, spi_cs2;
    assign spi1_mosi = spi_mosi;
    assign spi2_mosi = spi_mosi;
    assign spi1_clk = spi_clk;
    assign spi2_clk = spi_clk;
    assign spi_miso = !spi_cs1 ? spi1_miso : spi2_miso;
    assign spi1_cs = spi_cs1;
    assign spi2_cs = spi_cs2;

    spi_wb8 spi_inst(
        .I_wb_clk(clk),
        .I_wb_adr(cpu_adr[1:0]),
        .I_wb_dat(cpu_dat),
        .I_wb_stb(spi_wb_stb),
        .I_wb_we(cpu_we),
        .O_wb_dat(spi_wb_dat),
        .O_wb_ack(spi_wb_ack),
        .I_spi_miso(spi_miso),
        .O_spi_mosi(spi_mosi),
        .O_spi_clk(spi_clk),
        .O_spi_cs1(spi_cs1),
        .O_spi_cs2(spi_cs2)
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


    `ifdef EXTENSION_PRESENT
        reg vga_stb = 0;
        wire[7:0] vga_dat;
        wire[7:0] vga_r, vga_g, vga_b;
        wire[18:0] vga_ram_adr;
        wire vga_ram_req;
        wire vga_ack;


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
            .I_ram_dat(ram_dat),
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

    `endif

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


    reg ram_stb;
    wire ram_ack;
    `ifdef EXTENSION_PRESENT
        // if the extension board is present, use the external SRAM chip
        wire[7:0] sram_dat_to_chip;
        wire[7:0] sram_dat_from_chip;
        wire sram_output_enable;
        wire[18:0] sram_chip_adr;
        assign {sram_a0, sram_a1, sram_a2, sram_a3, sram_a4, sram_a5, sram_a6, sram_a7, sram_a8, sram_a9, sram_a10, sram_a11, sram_a12, sram_a13, sram_a14, sram_a15, sram_a16, sram_a17, sram_a18} = sram_chip_adr;

        sram512kx8_wb8_vga sram_inst(
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
            .I_vga_adr(vga_ram_adr),
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
            .I_wb_clk(clk),
            .I_wb_adr(cpu_adr[12:0]),
            .I_wb_dat(cpu_dat),
            .I_wb_stb(ram_stb),
            .I_wb_we(cpu_we),
            .O_wb_dat(ram_dat),
            .O_wb_ack(ram_ack)
        );
        assign ram_stall = 0;
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
      if(!uart_rts || !reset_button) begin
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
        `ifdef EXTENSION_PRESENT
                vga_stb = 0;
        `endif

        casez(cpu_adr[31:0])
            `ifdef EXTENSION_PRESENT
                {16'hFFFF, 3'b000, {13{1'b?}}}: begin //0xFFFF0000 - 0xFFFF1FFF: VGA
                    arbiter_dat_o = vga_dat;
                    arbiter_ack_o = vga_ack;
                    vga_stb = cpu_stb;
                end
            `endif


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
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end

        endcase

    end


endmodule
