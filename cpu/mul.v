`default_nettype none

module spu32_cpu_mul(
        input I_clk,
        input I_en,
        input I_reset,
        input[31:0] I_s1,
        input I_s1_signed,
        input[31:0] I_s2,
        input I_s2_signed,
        input I_hi,
        output[63:0] O_result,
        output O_busy
    );

    
    reg busy = 1'b0;
    reg[63:0] s1 = 64'b0;
    reg[63:0] s2 = 64'b0;
    reg[63:0] s1_next;
    reg[63:0] s2_next;
    reg s1_sign, s2_sign;
    reg[63:0] accumulator = 64'b0;
    reg[63:0] accumulator_next;

    assign O_result = accumulator;
    assign O_busy = busy;

`ifdef FORMAL
    reg[31:0] form_s1 = 32'b0, form_s2 = 32'b0;
    reg form_s1_signed = 1'b0, form_s2_signed = 1'b0;
    reg form_hi = 1'b0;
`endif


    always @(*) begin
        if(s2[0]) begin
            accumulator_next = accumulator + s1;
        end else begin
            accumulator_next = accumulator;
        end

        // left-shift s1
        s1_next = {s1[62:0], 1'b0};
        // right-shift s2
        s2_next = {1'b0, s2[63:1]};
    end

    always @(*) begin
        // determine value for sign extension
        s1_sign = I_s1_signed ? I_s1[31] : 1'b0;
        s2_sign = I_s2_signed ? I_s2[31] : 1'b0;
    end


    always @(posedge I_clk) begin
        if(!busy) begin
            if(I_en) begin
                // not busy, start mul
                accumulator <= 64'b0;
                // sign extend to 64 bit
                s1 <= {{32{s1_sign}}, I_s1};
                // Do sign-extension for s2 only if upper 32 bits are needed.
                // Otherwise do zero-extension to finish in up to 32 cycles.
                s2 <= {{32{s2_sign & I_hi}}, I_s2};
`ifdef FORMAL
                // remember input values for comparison with finished result
                form_s1 <= I_s1;
                form_s1_signed <= I_s1_signed;
                form_s2 <= I_s2;
                form_s2_signed <= I_s2_signed;
                form_hi <= I_hi;
`endif
                busy <= 1'b1;
            end
        end else begin
            if(s2 != 64'b0) begin
                accumulator <= accumulator_next;
                s1 <= s1_next;
                s2 <= s2_next;
            end else begin
                busy <= 1'b0;
            end
        end

        if(I_reset) begin
            busy <= 1'b0;
            accumulator <= 64'b0;
`ifdef FORMAL
            form_s1 <= 32'b0;
            form_s1_signed <= 1'b0;
            form_s2 <= 32'b0;
            form_s2_signed <= 1'b0;
            form_hi <= 1'b0;
`endif
        end

    end


// --- FORMAL VERIFICATION --- //

`ifdef FORMAL

    reg past_valid = 1'b0;
    reg[63:0] mul_unsigned_unsigned;
    reg signed[63:0] mul_signed_signed;
    reg signed[63:0] mul_signed_unsigned;

    always @(*) begin
        mul_unsigned_unsigned = {32'b0, form_s1} * {32'b0, form_s2};
        mul_signed_signed = $signed(form_s1) * $signed(form_s2);
        mul_signed_unsigned = $signed(form_s1) * $signed({32'b0, form_s2});
    end

    always @(posedge I_clk) begin
        past_valid <= 1'b1;

        assume(I_en == 1'b1);
        assume(I_reset == 1'b0);
        assume(I_s1 == 32'hF4321000 || I_s1 == 32'h07654321);
        assume(I_s2 == 32'hF0001234 || I_s2 == 32'h01234567);

        assume((I_s1_signed && I_s2_signed) || (!I_s1_signed && !I_s2_signed) || (I_s1_signed && !I_s2_signed));

        if(past_valid) begin

            if($past(busy) && !busy) begin

                // MUL
                if(!form_hi) begin
                    assert(accumulator[31:0] == mul_unsigned_unsigned[31:0]);
                end

                // MULH
                if(form_s1_signed && form_s2_signed && form_hi) begin
                    assert(accumulator[63:32] == mul_signed_signed[63:32]);
                end

                // MULHU
                if(!form_s1_signed && !form_s2_signed && form_hi) begin
                    assert(accumulator[63:32] == mul_unsigned_unsigned[63:32]);
                end

                // MULHSU
                if(form_s1_signed && !form_s2_signed && form_hi) begin
                    assert(accumulator[63:32] == mul_signed_unsigned[63:32]);
                end
            end
        end


    end


`endif



endmodule


