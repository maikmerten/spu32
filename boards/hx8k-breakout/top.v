`include "./cpu/cpu.v"
`include "./ram/ram4k_wb8.v"
`include "./leds/leds_wb8.v"
`include "./uart/uart_wb8.v"
`include "./spi/spi_wb8.v"
`include "./timer/timer_wb8.v"
`include "./rom/rom_wb8.v"


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
        output debug1, debug2
    );

    wire clk_pll, pll_locked;
    // generate 24 MHz clock
    SB_PLL40_CORE #(							
        .FEEDBACK_PATH("SIMPLE"),				
        .DIVR(4'b0000),         // DIVR =  0			
        .DIVF(7'b0111111),      // DIVF = 63			
        .DIVQ(3'b101),          // DIVQ =  5			
        .FILTER_RANGE(3'b001)   // FILTER_RANGE = 1		
    ) mypll (								
        .LOCK(pll_locked),					
        .RESETB(1'b1),						
        .BYPASS(1'b0),						
        .REFERENCECLK(clk_12mhz),				
        .PLLOUTGLOBAL(clk_pll)				
    );

    reg clk;

    //`define SLOWCLK 1
    `ifdef SLOWCLK
        reg[2:0] clockdiv = 0;
        always @(posedge clk_pll) begin
            clockdiv <= clockdiv + 1;
        end
        assign clk = clockdiv[2];

        localparam CLOCKFREQ = 3000000;
    `else
        localparam CLOCKFREQ = 24000000;
        assign clk = clk_pll;
    `endif

    assign debug1 = clk_pll;
    assign debug2 = clk;

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
    assign {led0, led1, led2, led3, led4, led5, led6, led7} = leds_value;

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


    // The iCE40 BRAMs always return zero for a while after device program and reset:
    // https://github.com/cliffordwolf/icestorm/issues/76
    // Assert reset for while until things should have settled.
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
        ram_stb = 0;
        leds_stb = 0;
        uart_stb = 0;
        spi0_stb = 0;
        timer_stb = 0;
        rom_stb = 0;

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

            default: begin
                arbiter_dat_o = ram_dat;
                arbiter_ack_o = ram_ack;
                ram_stb = cpu_stb;
            end
        endcase

    end


endmodule