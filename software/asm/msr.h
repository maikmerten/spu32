#ifndef MSR_DEFS
    #define MSR_DEFS

    // 0111 11xx xxxx - non-standard read/write 0x7c0
    // 1111 11xx xxxx - non-standard read-only  0xfc0

    #define MSR_STATUS_R 0xFC0
    #define MSR_STATUS_RW 0x7C0

    #define MSR_CAUSE_R 0xFC1
    #define MSR_CAUSE_RW 0x7C1

    #define MSR_EPC_R 0xFC2
    #define MSR_EPC_RW 0x7C2

    #define MSR_EVECT_R 0xFC3
    #define MSR_EVECT_RW 0x7C3
#endif