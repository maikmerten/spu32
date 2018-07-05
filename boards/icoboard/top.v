`include "./cpu/cpu.v"
`include "./ram/ram4k_wb8.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"
`include "./ram/sram64kx16_wb8.v"

module top(
        input clk_100mhz,
        // LED outputs on pmod header 1
        output pmod1_1, pmod1_2, pmod1_3, pmod1_4, pmod1_7, pmod1_8, pmod1_9, pmod1_10,
        // UART pins on pmod header 2
        input uart_rx, uart_rts,
        output uart_tx,
        // board LEDs
        output led1, led2,
        // SPI port 0
        input spi0_miso,
        output spi0_clk, spi0_mosi, spi0_cs,
        // push buttons
        input button0, button1,
        // SRAM
        output SRAM_A0, SRAM_A1, SRAM_A2, SRAM_A3, SRAM_A4, SRAM_A5, SRAM_A6, SRAM_A7, SRAM_A8, SRAM_A9, SRAM_A10, SRAM_A11, SRAM_A12, SRAM_A13, SRAM_A14, SRAM_A15,
        output SRAM_CE, SRAM_WE, SRAM_OE, SRAM_UB, SRAM_LB,
        inout SRAM_D0, SRAM_D1, SRAM_D2, SRAM_D3, SRAM_D4, SRAM_D5, SRAM_D6, SRAM_D7, SRAM_D8, SRAM_D9, SRAM_D10, SRAM_D11, SRAM_D12, SRAM_D13, SRAM_D14, SRAM_D15,
        // some debug signals on pmod port 3
        output debug0, debug1, debug2, debug3, debug4, debug5, debug6, debug7
    );

    wire clk_pll, pll_locked;

    // generate 25 MHz clock
    SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DELAY_ADJUSTMENT_MODE_FEEDBACK("FIXED"),
		.DELAY_ADJUSTMENT_MODE_RELATIVE("FIXED"),
		.PLLOUT_SELECT("GENCLK"),
		.FDA_FEEDBACK(4'b1111),
		.FDA_RELATIVE(4'b1111),
		.DIVR(4'b0000),
		.DIVF(7'b0000111),
		.DIVQ(3'b101),
		.FILTER_RANGE(3'b101)
	) pll (
		.PACKAGEPIN   (clk_100mhz),
		.PLLOUTGLOBAL (clk_pll),
		.LOCK         (pll_locked),
		.BYPASS       (1'b0      ),
		.RESETB       (1'b1      )
	);

    reg clk;

    `define SLOWCLK 1
    `ifdef SLOWCLK
        reg[2:0] clockdiv = 0;
        always @(posedge clk_pll) begin
            clockdiv <= clockdiv + 1;
        end
        assign clk = clockdiv[2];

        localparam CLOCKFREQ = 3125000;
    `else
        localparam CLOCKFREQ = 25000000;
        assign clk = clk_pll;
    `endif


    reg reset = 1;
    reg[7:0] resetcnt = 1;

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

    wire ram_ack;
    reg ram_stb;
    wire[7:0] ram_dat;

    ram4k_wb8 #(
        .RAMINITFILE("./software/asm/timer-test.dat")
    ) ram_inst (
	    .CLK_I(clk),
	    .STB_I(ram_stb),
	    .WE_I(cpu_we),
	    .ADR_I(cpu_adr[11:0]),
	    .DAT_I(cpu_dat),
	    .DAT_O(ram_dat),
	    .ACK_O(ram_ack)
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
    assign {pmod1_1, pmod1_2, pmod1_3, pmod1_4, pmod1_7, pmod1_8, pmod1_9, pmod1_10} = leds_value;

    reg uart_rx, uart_stb = 0;
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


    assign led1 = !uart_rx;
    assign led2 = !uart_tx;
    assign led3 = cpu_we;

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

    reg sram_stb;
    wire[7:0] sram_dat;
    wire sram_ack;
    wire[15:0] sram_dat_to_chip;
    wire[15:0] sram_dat_from_chip;
    wire sram_output_enable;
    //wire[15:0] sram_chip_dat;
    //assign {SRAM_D0, SRAM_D1, SRAM_D2, SRAM_D3, SRAM_D4, SRAM_D5, SRAM_D6, SRAM_D7, SRAM_D8, SRAM_D9, SRAM_D10, SRAM_D11, SRAM_D12, SRAM_D13, SRAM_D14, SRAM_D15} = sram_chip_dat;
    wire[15:0] sram_chip_adr;
    assign {SRAM_A0, SRAM_A1, SRAM_A2, SRAM_A3, SRAM_A4, SRAM_A5, SRAM_A6, SRAM_A7, SRAM_A8, SRAM_A9, SRAM_A10, SRAM_A11, SRAM_A12, SRAM_A13, SRAM_A14, SRAM_A15} = sram_chip_adr;

    sram64kx16_wb8 sram_inst(
        // wiring to wishbone bus
        .CLK_I(clk),
        .ADR_I(cpu_adr[16:0]),
        .DAT_I(cpu_dat),
        .STB_I(sram_stb),
        .WE_I(cpu_we),
        .DAT_O(sram_dat),
        .ACK_O(sram_ack),
        // wiring to SRAM chip
        .O_data(sram_dat_to_chip),
        .I_data(sram_dat_from_chip),
		.O_address(sram_chip_adr),
        .O_ce(SRAM_CE),
        .O_oe(SRAM_OE),
        .O_we(SRAM_WE),
        .O_ub(SRAM_UB),
        .O_lb(SRAM_LB),
        // output enable
        .O_output_enable(sram_output_enable)
    );
    
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance0 (
        .PACKAGE_PIN(SRAM_D0),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[0]),
        .D_IN_0(sram_dat_from_chip[0])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance1 (
        .PACKAGE_PIN(SRAM_D1),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[1]),
        .D_IN_0(sram_dat_from_chip[1])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance2 (
        .PACKAGE_PIN(SRAM_D2),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[2]),
        .D_IN_0(sram_dat_from_chip[2])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance3 (
        .PACKAGE_PIN(SRAM_D3),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[3]),
        .D_IN_0(sram_dat_from_chip[3])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance4 (
        .PACKAGE_PIN(SRAM_D4),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[4]),
        .D_IN_0(sram_dat_from_chip[4])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance5 (
        .PACKAGE_PIN(SRAM_D5),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[5]),
        .D_IN_0(sram_dat_from_chip[5])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance6 (
        .PACKAGE_PIN(SRAM_D6),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[6]),
        .D_IN_0(sram_dat_from_chip[6])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance7 (
        .PACKAGE_PIN(SRAM_D7),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[7]),
        .D_IN_0(sram_dat_from_chip[7])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance8 (
        .PACKAGE_PIN(SRAM_D8),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[8]),
        .D_IN_0(sram_dat_from_chip[8])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance9 (
        .PACKAGE_PIN(SRAM_D9),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[9]),
        .D_IN_0(sram_dat_from_chip[9])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance10 (
        .PACKAGE_PIN(SRAM_D10),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[10]),
        .D_IN_0(sram_dat_from_chip[10])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance11 (
        .PACKAGE_PIN(SRAM_D11),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[11]),
        .D_IN_0(sram_dat_from_chip[11])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance12 (
        .PACKAGE_PIN(SRAM_D12),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[12]),
        .D_IN_0(sram_dat_from_chip[12])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance13 (
        .PACKAGE_PIN(SRAM_D13),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[13]),
        .D_IN_0(sram_dat_from_chip[13])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance14 (
        .PACKAGE_PIN(SRAM_D14),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[14]),
        .D_IN_0(sram_dat_from_chip[14])
    );
    SB_IO #(.PIN_TYPE(6'b 1010_01), .PULLUP(1'b 0)) io_block_instance15 (
        .PACKAGE_PIN(SRAM_D15),
        .OUTPUT_ENABLE(sram_output_enable),
        .D_OUT_0(sram_dat_to_chip[15]),
        .D_IN_0(sram_dat_from_chip[15])
    );

    // The iCE40 BRAMs always return zero for a while after device program and reset:
    // https://github.com/cliffordwolf/icestorm/issues/76
    // Assert reset for while until things should have settled.
    always @(posedge clk) begin
      if(resetcnt != 0) begin
        reset <= 1;
        resetcnt <= resetcnt + 1;
      end else reset <= 0;

      // use button1 and UART rts (active low) for reset
      if(button1 | !uart_rts) begin
        resetcnt <= 1;
      end
    end

    // assign debug output
    assign debug0 = clk;
    assign debug1 = cpu_we;
    assign debug2 = SRAM_WE;
    assign debug3 = sram_output_enable;
    assign debug4 = SRAM_UB;
    assign debug5 = SRAM_LB;
    assign debug6 = sram_stb;



    // bus arbiter
    always @(*) begin
        ram_stb = 0;
        leds_stb = 0;
        uart_stb = 0;
        spi0_stb = 0;
        timer_stb = 0;
        rom_stb = 0;
        sram_stb = 0;

        casez(cpu_adr[31:11])

            {20'hFFFFF, 1'b0}: begin // 0xFFFFF000 - 0xFFFFF7FF: boot ROM
                    arbiter_dat_o = rom_dat;
                    arbiter_ack_o = rom_ack;
                    rom_stb = cpu_stb;
            end

            {20'hFFFFF, 1'b1}: begin // 0xFFFFF800 - 0xFFFFFFFF: I/O devices
                case(cpu_adr[10:8])
                    0: begin // 0xFFFFF8xx: UART
                        arbiter_dat_o = uart_dat;
                        arbiter_ack_o = uart_ack;
                        uart_stb = cpu_stb;
                    end

                    1: begin // 0xFFFFF9xx: SPI port 0
                        arbiter_dat_o = spi0_dat;
                        arbiter_ack_o = spi0_ack;
                        spi0_stb = cpu_stb;
                    end

                    // 2: 0xFFFFFAxx

                    // 3: 0xFFFFFBxx:

                    // 4: 0xFFFFFCxx 

                    5: begin // 0xFFFFFDxx: Timer
                        arbiter_dat_o = timer_dat;
                        arbiter_ack_o = timer_ack;
                        timer_stb = cpu_stb;
                    end

                    // 6: 0xFFFFFExx

                    default: begin // default I/O device: LEDs
                        arbiter_dat_o = leds_dat;
                        arbiter_ack_o = leds_ack;
                        leds_stb = cpu_stb;                      
                    end
                endcase
            end

            {1'b1, 20'b?}: begin
                    arbiter_dat_o = sram_dat;
                    arbiter_ack_o = sram_ack;
                    sram_stb = cpu_stb;
            end

            default: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end
        endcase

    end


endmodule