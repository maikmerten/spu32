`include "./cpu/busdefs.vh"

module cache(
		input I_clk,
		input I_en,
		input I_reset,
		input I_offer_data,
		input[2:0] I_busop,
		input[31:0] I_addr,
		input[31:0] I_invalidate_addr,
		input[31:0] I_data,
		output reg[31:0] O_data,
		output O_hit
	);

	// ENTRYBITS determines the size of the cache, everything else is computed from this
	localparam ENTRYBITS = 10;
	localparam ENTRIES = 2**ENTRYBITS;
	localparam ENTRYLOBIT = 2;
	localparam ENTRYHIBIT = ENTRYBITS + 1;
	localparam TAGLOBIT = ENTRYHIBIT + 1;
	localparam TAGHIBIT = ENTRYHIBIT + 15;

	reg[15:0] tags[ENTRIES-1:0]; // 256 tags, each 16 bit: 1 bit for "valid", 15 bits for address
	reg[31:0] data[ENTRIES-1:0]; // 256 words of storage

	wire cacheable_addr, cacheable_read, update_cache;
	wire[ENTRYBITS-1:0] entry;
	wire[14:0] tagaddr;

	// only aligned words are cached
	assign cacheable_addr = (I_addr[31:TAGHIBIT+1] == 0 && I_addr[1:0] == 0);
	assign cacheable_read = cacheable_addr && I_busop == `BUSOP_READW;
	assign update_cache = cacheable_read && I_offer_data;
	assign entry = I_addr[ENTRYHIBIT:ENTRYLOBIT];
	assign tagaddr = I_addr[TAGHIBIT:TAGLOBIT];

	// react to writes that can invalidate a cache line
	wire invalidate;
	wire[ENTRYBITS-1:0] entry_invalidate;
	assign invalidate = I_invalidate_addr[31:TAGHIBIT+1] == 0 && (I_busop == `BUSOP_WRITEB || I_busop == `BUSOP_WRITEH || I_busop == `BUSOP_WRITEW);
	assign entry_invalidate = I_invalidate_addr[ENTRYHIBIT:ENTRYLOBIT];

	// tag content
	reg[15:0] tag;
	assign O_hit = cacheable_read && tag == {1'b1, tagaddr};

	reg[ENTRYBITS-1:0] entrycounter = 0;

	wire[15:0] tagdata;
	wire[ENTRYBITS-1:0] tagentry;
	wire writetag;
	// on reset or invalidate, tags are zeroed out to get rid of the 'valid' flag
	assign tagdata = (I_reset || invalidate) ? 16'h0000 : {1'b1, tagaddr};
	// on reset, use a counter to address the tag to be cleared
	// note that this means that reset eeds to be asserted for at least 256 clocks!
	assign tagentry = I_reset ? entrycounter : (invalidate ? entry_invalidate : entry);
	// write to tag on reset, invalidate or when something is to be cached
	assign writetag = I_reset || invalidate || (I_en && update_cache);


	always @(posedge I_clk) begin

		if(I_en) begin
			tag <= tags[entry];

			O_data <= data[entry];

			if(update_cache) begin
				$display("+++++ updating cache entry %d with value %h", entry, I_data);
				data[entry] <= I_data;
			end
		end

		if(writetag) begin
			$display("### Updating tag %d with value %h", tagentry, tagdata);
			tags[tagentry] <= tagdata;
		end

		entrycounter <= entrycounter + 1;
	end


endmodule
