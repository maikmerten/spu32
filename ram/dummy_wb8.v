`default_nettype none

module dummy_wb8
	(
		input I_wb_clk,
		input I_wb_stb,
		output[7:0] O_wb_dat,
		output reg O_wb_ack
	);

	// Dummy device to write data to, always reads 0xFF

	assign O_wb_dat = 8'hFF;

	always @(posedge I_wb_clk) begin
		O_wb_ack <= I_wb_stb;
	end

endmodule