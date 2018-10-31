`include "./cpu/busdefs.vh"
`include "./cpu/cache.v"

module bus_wb8(
		input I_en,
		input[2:0] I_op,
		input[31:0] I_addr,
		input[31:0] I_data,
		output[31:0] O_data,
		output O_busy,

		// wired to outside world, RAM, devices etc.
		//naming of signals taken from Wishbone B4 spec
		input CLK_I,
		input ACK_I,
		input[7:0] DAT_I,
		input RST_I,
		output reg[31:0] ADR_O,
		output reg[7:0] DAT_O,
		output reg CYC_O,
		output reg STB_O,
		output reg WE_O
	);

	reg[31:0] buffer;
	assign O_data = buffer;

	reg busy = 0;
	assign O_busy = busy;

	reg[2:0] addrcnt = 0, ackcnt = 0, byte_target = 0;
	wire[31:0] busaddr;
	assign busaddr = I_addr + {{29{1'b0}}, addrcnt};
	reg signextend = 0;
	reg write = 0;

	reg mysign = 0;

	wire[31:0] cache_data;
	wire cache_hit;
	reg offer_data_to_cache = 0;
	cache cache_inst(
		.I_clk(CLK_I),
		.I_en(I_en),
		.I_reset(RST_I),
		.I_offer_data(offer_data_to_cache),
		.I_busop(I_op),
		.I_addr(I_addr),
		.I_invalidate_addr(busaddr),
		.I_data(buffer),
		.O_data(cache_data),
		.O_hit(cache_hit)
	);

	always @(*) begin
		// determine number of bytes to be processed
		case(I_op)
			`BUSOP_READW, `BUSOP_WRITEW: byte_target = 4;
			`BUSOP_READH, `BUSOP_READHU, `BUSOP_WRITEH: byte_target = 2;
			default: byte_target = 1;
		endcase

		// determine if sign extension is requested
		case(I_op)
			`BUSOP_READBU, `BUSOP_READHU: signextend = 0;
			default: signextend = 1;
		endcase

		// determine if a write operation is requested
		case(I_op)
			`BUSOP_WRITEB, `BUSOP_WRITEH, `BUSOP_WRITEW: write = 1;
			default: write = 0;
		endcase
	end

	always @(*) begin
		mysign = DAT_I[7] & signextend;
	end


	always @(posedge CLK_I) begin
		WE_O <= 0;
		CYC_O <= 0;
		STB_O <= 0;
		busy <= 0;
		offer_data_to_cache <= 0;

		if(I_en) begin
			// if enabled, act
			WE_O <= write;
			CYC_O <= 1;
			busy <= 1;

			//`define CACHE 1
			`ifdef CACHE
			if(addrcnt == 1 && I_op == `BUSOP_READW && cache_hit) begin
				busy <= 0;
				ackcnt <= 0;
				addrcnt <= 0;
				buffer <= cache_data;
			end else
			`endif
			if(ackcnt != byte_target) begin
				// we haven't yet received the proper number of ACKs, so we need to
				// output addresses and receive ACKs
				if(addrcnt != byte_target) begin
					STB_O <= 1;
					ADR_O <= busaddr;

					// put data on bus for current address
					case(addrcnt)
						0:			DAT_O <= I_data[7:0];
						1: 			DAT_O <= I_data[15:8];
						2: 			DAT_O <= I_data[23:16];
						default:	DAT_O <= I_data[31:24];
					endcase

					// TODO: only increment addrcnt when STALL_I is not asserted
					addrcnt <= addrcnt + 1;
				end

				if(ACK_I) begin
					// yay, ACK received, read data and put into buffer
					case (ackcnt)
						0:			buffer <= {{24{mysign}}, DAT_I};	
						1:			buffer[31:8] <= {{16{mysign}}, DAT_I};	
						2:			buffer[23:16] <= DAT_I;
						default: begin
							buffer[31:24] <= DAT_I;
							`ifdef CACHE
							offer_data_to_cache <= 1;
							`endif
						end
					endcase
					ackcnt <= ackcnt + 1;
				end
			end else begin
				// reached the correct number of ACKs, prepare for next request
				busy <= 0;
				ackcnt <= 0;
				addrcnt <= 0;
			end

		end

		if(RST_I) begin
			ackcnt <= 0;
			addrcnt <= 0;
		end

	end


endmodule
