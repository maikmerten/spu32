#ifndef LIBSPU32
#define LIBSPU32

    enum {
        CAUSE_INTERRUPT = 0x8000000B,
        CAUSE_INVALIDINSTR = 0x00000002,
        CAUSE_EBREAK = 0x00000003,
        CAUSE_ECALL = 0x0000000B
    };

    inline int read_msr_status();
    inline int write_msr_status();

    inline int read_msr_cause();
    inline int write_msr_cause();

    inline int read_msr_epc();
    inline int write_msr_epc();

    inline int read_msr_evect();
    inline int write_msr_evect(int vec);

    int get_interrupt_enabled();
    void enable_interrupt();
    void disable_interrupt();
    int get_interrupt_pending();


#endif