`default_nettype none

module spu32_cpu_div(
        input I_clk,
        input I_en,
        input[31:0] I_dividend,
        input[31:0] I_divisor,
        input I_divide,     // divide (1) or compute remainder (0)
        input I_signed_op,  // DIV/REM (1) or DIVU/REMU (0)
        input I_reset,
        output reg[31:0] O_result,
        output O_busy
    );

    // This module implements the approach of PicoRV32's division unit,
    // which was written by Claire Xenia Wolf <claire@yosyshq.com>.
    // The overall approach is hers, all bugs in this implementation are mine.

    reg[31:0] quotient = 0;
    reg[31:0] quot_mask = 0;
    reg[31:0] dividend = 0;
    reg[62:0] divisor = 0;

    wire div_signed = I_divide && I_signed_op;
    wire rem_signed = !I_divide && I_signed_op;

    wire neg_dividend = (I_signed_op && I_dividend[31]);
    wire neg_divisor  = (I_signed_op && I_divisor[31]);
    wire neg_result   = (div_signed && (I_dividend[31] != I_divisor[31]) && (I_divisor != 0))
                      | (rem_signed && I_dividend[31]);

    // select quotient or dividend depending on whether we divide or compute the remainder
    wire[31:0] result = I_divide ? quotient : dividend;

    reg busy = 0;
    assign O_busy = busy;
    reg finished = 0;

//`define SUBTRACTCOMPARE
`ifdef SUBTRACTCOMPARE
    // subtraction with 33 bits for underflow detection
    wire[32:0] dividend_minus_divisor = {1'b0, dividend} - {1'b0, divisor[31:0]};
    wire divisor_lessequal_dividend = (divisor[62:32] == 0) && !dividend_minus_divisor[32];
`endif

    always @(posedge I_clk) begin
        case(busy)
            1'b0: begin // idle state
                quotient <= 0;
                quot_mask <= (1 << 31);
                finished <= 0;                
                if(I_en) begin
                    dividend <= neg_dividend ? -I_dividend : I_dividend;
                    divisor <= (neg_divisor  ? -I_divisor  : I_divisor) << 31;
                    busy <= 1;
                end
            end

            1'b1: begin // busy state
                if(finished) begin
                    O_result <= neg_result ? -result : result;
                    busy <= 0;
                end

`ifdef SUBTRACTCOMPARE
                if(divisor_lessequal_dividend) begin
                    dividend <= dividend_minus_divisor[31:0];
                    quotient <= quotient | quot_mask;
                end
`else

                if(divisor <= dividend) begin
                    dividend <= dividend - divisor;
                    quotient <= quotient | quot_mask;
                end
`endif
                finished <= quot_mask[0];
                divisor <= divisor >> 1;
                quot_mask <= quot_mask >> 1;
            end
        endcase

        // reset logic
        if(I_reset) begin
            busy <= 0;
        end
    end
    
endmodule