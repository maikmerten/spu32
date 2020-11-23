`default_nettype none

module spu32_cpu_shifter (
		input[31:0] I_data,
		input[4:0] I_shift,
		input I_signextend,
		input I_leftshift,
		output[31:0] O_data
	);

	wire sign = I_signextend & I_data[31];

	wire[31:0] input_reversed, output_reversed;
	
	// if left shift: reverse input for right-shifter
	genvar i;
	for(i = 0; i < 32; i = i + 1) begin
		assign input_reversed[i] = I_data[31 - i];
	end
	wire[31:0] shifter_input = I_leftshift ? input_reversed	: I_data[31:0];

    // logarithmic right shifter
	wire[31:0] rshift4 = I_shift[4] ? {{16{sign}}, shifter_input[31:16]} : shifter_input;
	wire[31:0] rshift3 = I_shift[3] ? {{8{sign}}, rshift4[31:8]} : rshift4;
	wire[31:0] rshift2 = I_shift[2] ? {{4{sign}}, rshift3[31:4]} : rshift3;
	wire[31:0] rshift1 = I_shift[1] ? {{2{sign}}, rshift2[31:2]} : rshift2;
	wire[31:0] rshift0 = I_shift[0] ? {{1{sign}}, rshift1[31:1]} : rshift1;

	// if left shift: reverse output of right-shifter
	for(i = 0; i < 32; i = i + 1) begin
		assign output_reversed[i] = rshift0[31 - i];
	end
	assign O_data = I_leftshift ? output_reversed : rshift0;

endmodule


`ifdef FORMAL
// --- formal verification code ---

module spu32_cpu_shifter_formal(
		input I_clk,
		input signed[31:0] I_data,
		input[4:0] I_shift,
		input I_signextend,
		input I_leftshift,
	);

	reg signed[31:0] data;
	reg[4:0] shift;
	reg signextend, leftshift;
	wire[31:0] shifter_output;
	reg[31:0] result;

	spu32_cpu_shifter spu32_cpu_shifter_inst(
		.I_data(data),
		.I_shift(shift),
		.I_signextend(signextend),
		.I_leftshift(leftshift),
		.O_data(shifter_output)
	);

	reg past_valid = 1'b0;

	always @(posedge I_clk) begin
		assume((I_leftshift && !I_signextend) || !I_leftshift);

		past_valid <= 1'b1;
		data <= I_data;
		shift <= I_shift;
		signextend <= I_signextend;
		leftshift <= I_leftshift;
		result <= shifter_output;

		if(past_valid) begin
			if($past(leftshift)) begin
				// check left shift result
				if($past(signextend) == 1'b0) begin
					assert(result == ($past(data) << $past(shift)));
				end
			end else begin
				// check right shift results
				if($past(signextend)) begin
					// with sign extension
					assert($signed(result) == ($signed($past(data)) >>> $past(shift)));
				end else begin
					// without sign extension
					assert(result == ($past(data) >> $past(shift)));
				end
			end
		end
	end

endmodule

`endif
