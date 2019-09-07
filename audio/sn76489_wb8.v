module sn76489_oscillator(
        input I_clk,
        input[9:0] I_freq,
        output O_voice
    );

    reg[9:0] counter = 0;
    reg out = 0;

    assign O_voice = out;

    always @(posedge I_clk) begin
        counter <= counter - 1;
        if(counter == 0) begin
            out <= !out;
            counter <= I_freq;
        end
    end
endmodule


module sn76489_noise(
        input I_clk,
        input[2:0] I_ctrl,
        input[9:0] I_freq,
        input I_reset_noise,
        output O_voice,
        output O_reset_ack
    );

    reg reset = 0;
    assign O_reset_ack = reset;

    reg[9:0] counter = 0;
    reg[15:0] shiftreg = 16'h8000;
    assign O_voice = shiftreg[0];

    reg flipbit = 0;

    wire[1:0] rate;
    assign rate = I_ctrl[1:0];
    wire white_noise;
    assign white_noise = I_ctrl[2];

    always @(posedge I_clk) begin
        counter <= counter - 1;
        if(counter == 0) begin
            flipbit <= !flipbit;
            case(rate)
                2'b00: counter <= 'h10;
                2'b01: counter <= 'h20;
                2'b10: counter <= 'h40;
                2'b11: counter <= I_freq;
            endcase

            if(flipbit == 0) begin
                if(white_noise) begin
                    shiftreg <= {shiftreg[3] ^ shiftreg[0], shiftreg[15:1]};
                end else begin
                    shiftreg <= {shiftreg[0], shiftreg[15:1]};
                end
            end
        end

        if(I_reset_noise != reset) begin
            shiftreg <= 16'h8000;
            reset <= I_reset_noise;
        end
    end
endmodule


module sn76489_mixer(
        input I_voice0,
        input I_voice1,
        input I_voice2,
        input I_voice3,
        input[3:0] I_voice0_att,
        input[3:0] I_voice1_att,
        input[3:0] I_voice2_att,
        input[3:0] I_voice3_att,
        output reg[7:0] O_audio
    );

    function[5:0] voice_audio;
        input I_voice;
        input[3:0] I_att;
        case({I_voice, I_att})
            {1'b1, 4'b0000}: voice_audio = 6'd63;
            {1'b1, 4'b0001}: voice_audio = 6'd59;
            {1'b1, 4'b0010}: voice_audio = 6'd55;
            {1'b1, 4'b0011}: voice_audio = 6'd50;
            {1'b1, 4'b0100}: voice_audio = 6'd46;
            {1'b1, 4'b0101}: voice_audio = 6'd42;
            {1'b1, 4'b0110}: voice_audio = 6'd38;
            {1'b1, 4'b0111}: voice_audio = 6'd34;
            {1'b1, 4'b1000}: voice_audio = 6'd29;
            {1'b1, 4'b1001}: voice_audio = 6'd25;
            {1'b1, 4'b1010}: voice_audio = 6'd21;
            {1'b1, 4'b1011}: voice_audio = 6'd17;
            {1'b1, 4'b1100}: voice_audio = 6'd13;
            {1'b1, 4'b1101}: voice_audio = 6'd8;
            {1'b1, 4'b1110}: voice_audio = 6'd4;
            default: voice_audio = 6'd0;
        endcase
    endfunction

    always @(*) begin
        O_audio = {1'b0, {1'b0, voice_audio(I_voice0, I_voice0_att)} + {1'b0, voice_audio(I_voice1, I_voice1_att)}} + {1'b0, {1'b0, voice_audio(I_voice2, I_voice2_att)} + {1'b0, voice_audio(I_voice3, I_voice3_att)}};
    end
endmodule


module sn76489_modulator
    #(
        parameter BITS = 8,
        parameter PDM = 1
    )
    (
        input I_clk,
        input[7:0] I_audio_pcm,
        output reg O_audio_modulated
    );

    if(PDM) begin
        // Pulse-Density Modulation (PDM)
        localparam MAX = 2**BITS - 1;
        reg[(BITS - 1):0] error;

        wire out;
        assign out = (I_audio_pcm >= error);

        always @(posedge I_clk) begin
            O_audio_modulated <= out;
		    error <= out ? (error + (MAX - I_audio_pcm)) : (error - I_audio_pcm);
        end
    end else begin
        // Pulse-Width Modulation (PWM)
        reg[(BITS - 1):0] pwm_counter = 0;
        always @(posedge I_clk) begin
            O_audio_modulated <= pwm_counter < I_audio_pcm;
            pwm_counter <= pwm_counter + 1;
        end
    end
endmodule


module sn76489_wb8
    #(
        parameter FREQDIVIDE = 55
    )
    (
        // Wisbhone B4 signals
        input I_wb_clk,
        input[7:0] I_wb_dat,
        input I_wb_stb,
        input I_wb_we,
        output reg O_wb_ack,
        output[7:0] O_wb_dat,

        // reset signal
        input I_reset,

        // audio output
        output[7:0] O_audio_pcm,
        output O_audio_modulated
    );

    assign O_wb_dat = 0;

    // divide audio clock from bus clock
    reg clk = 0;
    reg[($clog2(FREQDIVIDE) - 1):0] clk_counter;
    always @(posedge I_wb_clk) begin
        clk_counter <= clk_counter - 1;
        if(clk_counter == 0) begin
            clk <= !clk;
            clk_counter <= FREQDIVIDE;
        end
    end

    // voice control registers
    reg[9:0] tone1_freq; // register 000
    reg[3:0] tone1_att;  // register 001
    reg[9:0] tone2_freq; // register 010
    reg[3:0] tone2_att;  // register 011
    reg[9:0] tone3_freq; // register 100
    reg[3:0] tone3_att;  // register 101
    reg[2:0] noise_ctrl; // register 110
    reg[3:0] noise_att;  // register 111


    // instantiate voices
    wire tone1_output, tone2_output, tone3_output, noise_output, noise_reset_ack;
    reg reset_noise;
    sn76489_oscillator tone1_inst(
        .I_clk(clk),
        .I_freq(tone1_freq),
        .O_voice(tone1_output)
    );
    sn76489_oscillator tone2_inst(
        .I_clk(clk),
        .I_freq(tone2_freq),
        .O_voice(tone2_output)
    );
    sn76489_oscillator tone3_inst(
        .I_clk(clk),
        .I_freq(tone3_freq),
        .O_voice(tone3_output)
    );
    sn76489_noise noise_inst(
        .I_clk(clk),
        .I_ctrl(noise_ctrl),
        .I_freq(tone3_freq),
        .I_reset_noise(reset_noise),
        .O_voice(noise_output),
        .O_reset_ack(noise_reset_ack)
    );
    

    // instantiate mixer
    wire[7:0] mixer_audio;
    sn76489_mixer mixer_inst(
        .I_voice0(tone1_output),
        .I_voice1(tone2_output),
        .I_voice2(tone3_output),
        .I_voice3(noise_output),
        .I_voice0_att(tone1_att),
        .I_voice1_att(tone2_att),
        .I_voice2_att(tone3_att),
        .I_voice3_att(noise_att),
        .O_audio(mixer_audio)
    );
    assign O_audio_pcm = mixer_audio;

    sn76489_modulator modulator_inst(
        .I_clk(I_wb_clk),
        .I_audio_pcm(mixer_audio),
        .O_audio_modulated(O_audio_modulated)
    );


    reg[2:0] register;
    reg update;
    reg[6:0] update_data;

    // bus logic
    always @(posedge I_wb_clk) begin
        update <= 0;
        if(I_wb_stb && I_wb_we) begin
            update <= 1;
            update_data <= {I_wb_dat[7], I_wb_dat[5:0]};
            if(I_wb_dat[7]) begin
                register <= I_wb_dat[6:4];
            end
        end

        if(update) begin
            casez({register, update_data[6]})
                4'b0000: tone1_freq[9:4] <= update_data[5:0];
                4'b0001: tone1_freq[3:0] <= update_data[3:0];
                4'b001?: tone1_att <= update_data[3:0];
                4'b0100: tone2_freq[9:4] <= update_data[5:0];
                4'b0101: tone2_freq[3:0] <= update_data[3:0];
                4'b011?: tone2_att <= update_data[3:0];
                4'b1000: tone3_freq[9:4] <= update_data[5:0];
                4'b1001: tone3_freq[3:0] <= update_data[3:0];
                4'b101?: tone3_att <= update_data[3:0];
                4'b110?: begin
                    noise_ctrl <= update_data[2:0];
                    // noise shift register is cleared when writing to noise register
                    reset_noise <= !noise_reset_ack;
                end
                4'b111?: noise_att <= update_data[3:0];
            endcase
        end

        if(I_reset) begin
            // on reset, mute all voices
            tone1_att <= 4'b1111;
            tone2_att <= 4'b1111;
            tone3_att <= 4'b1111;
            noise_att <= 4'b1111;
            noise_ctrl <= 3'b100;

            tone1_freq <= 10'b1111111111;
            tone2_freq <= 10'b0111111111;
            tone3_freq <= 10'b0011111111;

            reset_noise <= !noise_reset_ack;
        end

        O_wb_ack <= I_wb_stb;
    end

endmodule