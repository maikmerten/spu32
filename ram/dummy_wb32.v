`default_nettype none

module dummy_wb32
	(
		input I_wb_clk,
		input I_wb_stb,
		output[31:0] O_wb_dat,
		output reg O_wb_ack
	);

	// Dummy device to write data to, always reads 0xFF

	assign O_wb_dat = 32'hFFFFFFFF;

	always @(posedge I_wb_clk) begin
		O_wb_ack <= I_wb_stb;
	end

endmodule