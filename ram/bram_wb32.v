module bram_wb32
    #(
        parameter ADDRBITS = 11, // by default, 8 KB of BRAM
        parameter RAMINITFILE = "./ram/raminit.dat"
    )
    (
        input I_wb_clk,
        input I_wb_stb,
        input I_wb_we,
        input[ADDRBITS-1:0] I_wb_adr,
        input[31:0] I_wb_dat,
        input[3:0] I_wb_sel,
        output reg [31:0] O_wb_dat,
        output reg O_wb_ack
    );

    localparam RAMSIZE = 4 * (2**ADDRBITS);

    reg[7:0] ram3 [RAMSIZE-1:0];
    reg[7:0] ram2 [RAMSIZE-1:0];
    reg[7:0] ram1 [RAMSIZE-1:0];
    reg[7:0] ram0 [RAMSIZE-1:0];
    
    //initial $readmemh(RAMINITFILE, ram, 0, RAMSIZE-1);

    wire write = I_wb_stb & I_wb_we;
    wire read = I_wb_stb & !I_wb_we;

    wire write3 = write & I_wb_sel[3];
    wire write2 = write & I_wb_sel[2];
    wire write1 = write & I_wb_sel[1];
    wire write0 = write & I_wb_sel[0];


    always @(posedge I_wb_clk) begin
        if(write3) ram3[I_wb_adr] <= I_wb_dat[31:24];
        if(write2) ram2[I_wb_adr] <= I_wb_dat[23:16];
        if(write1) ram1[I_wb_adr] <= I_wb_dat[15:8];
        if(write0) ram0[I_wb_adr] <= I_wb_dat[7:0];


        if(read) O_wb_dat[31:24] <= ram3[I_wb_adr];
        if(read) O_wb_dat[23:16] <= ram2[I_wb_adr];
        if(read) O_wb_dat[15:8] <= ram1[I_wb_adr];
        if(read) O_wb_dat[7:0] <= ram0[I_wb_adr];

        O_wb_ack <= I_wb_stb;
    end

endmodule