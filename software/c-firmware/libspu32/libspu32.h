#ifndef LIBSPU32
#define LIBSPU32

    enum {
        CAUSE_INTERRUPT = 0x8000000B,
        CAUSE_INVALIDINSTR = 0x00000002,
        CAUSE_EBREAK = 0x00000003,
        CAUSE_ECALL = 0x0000000B
    };

    int read_msr_status();
    int write_msr_status();

    int read_msr_cause();
    int write_msr_cause();

    int read_msr_epc();
    int write_msr_epc();

    int read_msr_evect();
    int write_msr_evect(int vec);

    int get_interrupt_enabled();
    void enable_interrupt();
    void disable_interrupt();
    int get_interrupt_pending();

    int get_milli_time();
    void request_milli_time_interrupt(int timeoffset);
    void ack_milli_time_interrupt();

    char get_leds_value();
    void set_leds_value(char value);

    int get_prng_value();
    void set_prng_seed(int seed);


#endif