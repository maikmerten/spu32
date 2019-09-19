`ifndef BUSDEFS
    `define BUSDEFS 1

    `define BUSOP_READB     3'b000
    `define BUSOP_READBU	3'b001
    `define BUSOP_READH     3'b010
    `define BUSOP_READHU	3'b011
    `define BUSOP_READW     3'b100

    `define BUSOP_WRITEB	3'b101
    `define BUSOP_WRITEH	3'b110
    `define BUSOP_WRITEW	3'b111

`endif
