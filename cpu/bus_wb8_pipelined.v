`include "./cpu/busdefs.vh"

module bus_wb8_pipelined(
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
	reg signextend = 0;
	reg write = 0;

	reg mysign = 0;

	// states of internal state machine
	localparam IDLE	= 0;
	localparam ACTIVE = 1;
	reg[0:0] state = IDLE;
	


	always @(posedge CLK_I) begin
		if(I_en) begin

			case(state)
			
				IDLE: begin // in idle state, evaluate requested op
					signextend <= 1;
					busy <= 1;
					addrcnt <= 0;
					ackcnt <= 0;
					write <= 0;

					WE_O <= 0;
					CYC_O <= 0;
					STB_O <= 0;


					case(I_op)
						`BUSOP_READB: begin
							byte_target <= 1; // read 1 byte
							state <= ACTIVE;
						end

						`BUSOP_READBU: begin
							byte_target <= 1; // read 1 byte
							signextend <= 0;
							state <= ACTIVE;
						end

						`BUSOP_READH: begin
							byte_target <= 2; // read 2 bytes
							state <= ACTIVE;
						end

						`BUSOP_READHU: begin
							byte_target <= 2; // read 2 bytes
							signextend <= 0;
							state <= ACTIVE;
						end

						`BUSOP_READW: begin
							byte_target <= 4; // read 4 bytes
							state <= ACTIVE;
						end


						`BUSOP_WRITEB: begin
							byte_target <= 1; // write 1 byte
							write <= 1;
							state <= ACTIVE;
						end

						`BUSOP_WRITEH: begin
							byte_target <= 2; // write 2 bytes
							write <= 1;
							state <= ACTIVE;
						end

						`BUSOP_WRITEW: begin
							byte_target <= 4; // write 4 bytes
							write <= 1;
							state <= ACTIVE;
						end
					endcase
				end

				ACTIVE: begin
					WE_O <=  write;
					CYC_O <= 1;
					STB_O <= 0;
					
					if(ackcnt < byte_target) begin
						// we haven't yet received the proper number of ACKs, so we need to
						// output addresses and receive ACKs
						if(addrcnt < byte_target) begin
							STB_O <= 1;
							ADR_O <= I_addr + addrcnt;

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
							mysign = DAT_I[7] & signextend;
							// yay, ACK received, read data and put into buffer
							case (ackcnt)
								0:			buffer <= {{24{mysign}}, DAT_I};	
								1:			buffer[31:8] <= {{16{mysign}}, DAT_I};	
								2:			buffer[23:16] <= DAT_I;
								default:	buffer[31:24] <= DAT_I;
							endcase
							ackcnt <= ackcnt + 1;
						end
					
					end else begin
						// we received all ACKs we needed, return to IDLE state
						WE_O <= 0;
						CYC_O <= 0;
						STB_O <= 0;
						busy <= 0;
						state <= IDLE;
					end
				end
				
			endcase
		end

		if(RST_I) begin
			WE_O <= 0;
			STB_O <= 0;
			CYC_O <= 0;
			busy <= 0;
			state <= IDLE;
		end

	end


endmodule
