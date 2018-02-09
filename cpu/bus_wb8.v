`include "./cpu/busdefs.vh"

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

	reg[1:0] byte = 0, byte_target = 0;
	reg signextend = 0;
	reg mysign = 0;

	// states of internal state machine
	`define IDLE		0
	`define READ_START	1
	`define READ_FINISH	2
	`define WRITE_START	3
	`define WRITE_FINISH	4
	reg[2:0] state = `IDLE;
	


	always @(posedge CLK_I) begin
		if(I_en) begin

			// compute memory address
			ADR_O <= I_addr + byte;

			case(state)
			
				`IDLE: begin // in idle state, evaluate requested op
					signextend <= 1;
					busy <= 1;
					byte <= 0;

					case(I_op)
						`BUSOP_READB: begin
							byte_target <= 0; // read 1 byte
							state <= `READ_START;
						end

						`BUSOP_READBU: begin
							byte_target <= 0; // read 1 byte
							signextend <= 0;
							state <= `READ_START;
						end

						`BUSOP_READH: begin
							byte_target <= 1; // read 2 bytes
							state <= `READ_START;
						end

						`BUSOP_READHU: begin
							byte_target <= 1; // read 2 bytes
							signextend <= 0;
							state <= `READ_START;
						end

						`BUSOP_READW: begin
							byte_target <= 3; // read 4 bytes
							state <= `READ_START;
						end


						`BUSOP_WRITEB: begin
							byte_target <= 0; // write 1 byte
							state <= `WRITE_START;
						end

						`BUSOP_WRITEH: begin
							byte_target <= 1; // write 2 bytes
							state <= `WRITE_START;
						end

						`BUSOP_WRITEW: begin
							byte_target <= 3; // write 4 bytes
							state <= `WRITE_START;
						end
					endcase
				end

				`READ_START: begin
					WE_O <=  0;
					CYC_O <= 1;
					STB_O <= 1;
					state <= `READ_FINISH;
				end

				`READ_FINISH: begin
					if(ACK_I) begin
						STB_O <= 0;

						mysign = DAT_I[7] & signextend;

						case (byte)
							0: buffer <= {{24{mysign}}, DAT_I};	
							1: buffer[31:8] <= {{16{mysign}}, DAT_I};	
							2: buffer[23:16] <= DAT_I;
							3: buffer[31:24] <= DAT_I;
						endcase

						if(byte < byte_target) begin
							byte <= byte + 1;
							state <= `READ_START;
						end else begin
							busy <= 0;
							CYC_O <= 0;
							byte <= 0;
							state <= `IDLE;
						end
					end
				end


				`WRITE_START: begin
					WE_O <= 1;
					CYC_O <= 1;
					STB_O <= 1;

					case(byte)
						0: DAT_O <= I_data[7:0];
						1: DAT_O <= I_data[15:8];
						2: DAT_O <= I_data[23:16];
						3: DAT_O <= I_data[31:24];
					endcase

					state <= `WRITE_FINISH;
				end

				`WRITE_FINISH: begin
					if(ACK_I) begin
						WE_O <= 0;
						STB_O <= 0;


						if(byte < byte_target) begin
							byte <= byte + 1;
							state <= `WRITE_START;
						end else begin
							busy <= 0;
							CYC_O <= 0;
							byte <= 0;
							state <= `IDLE;
						end
					end
				end

				
			endcase
		end

		if(RST_I) begin
			WE_O <= 0;
			STB_O <= 0;
			CYC_O <= 0;
			busy <= 0;
			state <= `IDLE;
		end

	end


endmodule
