module rom_wb32
	#(
		parameter ROMINITFILE = "./rom/rominit.dat32"
	)
	(
		input I_wb_clk,
		input I_wb_stb,
		input[7:0] I_wb_adr,
		output reg [31:0] O_wb_dat,
		output reg O_wb_ack
	);

	reg[31:0] rom [255:0];
	
	initial $readmemh(ROMINITFILE, rom, 0, 255);

	always @(posedge I_wb_clk) begin
		if(I_wb_stb) begin
			O_wb_dat <= rom[I_wb_adr];
		end
    	O_wb_ack <= I_wb_stb;
	end

endmodule