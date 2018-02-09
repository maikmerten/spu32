module mux32x2(
    input[31:0] port0,
    input[31:0] port1,
    input[0:0]  sel,
    output reg[31:0] out
    );

    always @(*) begin
      case(sel)
        0:          out <= port0;
        default:    out <= port1;
      endcase
    end

endmodule


module mux32x3(
    input[31:0] port0,
    input[31:0] port1,
    input[31:0] port2,
    input[1:0]  sel,
    output reg[31:0] out
    );

    always @(*) begin
      case(sel)
        0:          out <= port0;
        1:          out <= port1;
        default:    out <= port2;
      endcase
    end

endmodule


module mux32x4(
    input[31:0] port0,
    input[31:0] port1,
    input[31:0] port2,
    input[31:0] port3,
    input[1:0]  sel,
    output reg[31:0] out
    );

    always @(*) begin
      case(sel)
        0:          out <= port0;
        1:          out <= port1;
        2:          out <= port2;
        default:    out <= port3;
      endcase
    end

endmodule

