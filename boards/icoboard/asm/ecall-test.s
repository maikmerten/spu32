.section .text
 
.global _start

# 0111 11xx xxxx - non-standard read/write 0x7c0
# 1111 11xx xxxx - non-standard read-only  0xfc0

#define MSR_STATUS_R 0xFC0
#define MSR_STATUS_RW 0x7C0

#define MSR_CAUSE_R 0xFC1
#define MSR_CAUSE_RW 0x7C1

#define MSR_EPC_R 0xFC2
#define MSR_EPC_RW 0x7C2

main:
    li a0, 0
    j loop
    nop
    nop

########## trap handler ############
.=16
trap:
    # push a0 to LEDs
    sb a0, -1(zero)

    # read EPC and increment by 4
    csrrw t0, MSR_EPC_R, x0
    addi t0, t0, 4
    csrw MSR_EPC_RW, t0

    mret
##### end of trap handler ##########

loop:

    ecall
    addi a0, a0, 1;

    li t0, 99999
delay: 
    addi t0, t0, -1
    bnez t0, delay

	j loop

.size	main, .-main