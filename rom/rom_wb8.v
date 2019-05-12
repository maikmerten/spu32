module rom_wb8
	#(
		parameter ROMINITFILE = "./rom/rominit.dat"
	)
	(
		input I_wb_clk,
		input I_wb_stb,
		input[8:0] I_wb_adr,
		output reg [7:0] O_wb_dat,
		output reg O_wb_ack
	);

	reg[7:0] rom [511:0];
	
	initial $readmemh(ROMINITFILE, rom, 0, 511);

	always @(posedge I_wb_clk) begin
		if(I_wb_stb) begin
			O_wb_dat <= rom[I_wb_adr];
		end
    	O_wb_ack <= I_wb_stb;
	end

endmodule