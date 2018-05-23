#include "devices.h"
#include "msr.h"

.section .text
 
.global _start

main:
    li sp, 1024
    li a0, 0
    j interrupt_setup
    nop

########## trap handler ############
.=16
trap:
    # push registers to stack that will be modified
    addi sp, sp, -4
    sw t0, 0(sp)

    # push a0 to LEDs
    sb a0, DEV_LED(zero)

    # check cause to distinguish interrupts from traps
    # interrupts have most significant bit set to 1
    csrrw t0, MSR_CAUSE_R, x0
    blt t0, zero, trap_return

    # for software interrupts: read EPC and increment by 4 to form return address
    csrrw t0, MSR_EPC_R, x0
    addi t0, t0, 4
    csrrw zero, MSR_EPC_RW, t0

trap_return:
    # the following instruction should do nothing (writing to read-only MSR)
    csrrw zero, MSR_EPC_R, zero

    # restore registers and return from trap handler
    lw t0, 0(sp)
    addi sp, sp, 4
    mret
##### end of trap handler ##########

interrupt_setup:
    # read status register
    csrrw t1, MSR_STATUS_R, zero
    # set least-significant bit (interrupt enable)
    ori t1, t1, 1
    # write back to status register
    csrrw zero, MSR_STATUS_RW, t1

loop:

    ecall
    addi a0, a0, 1;

    li t0, 99999
delay: 
    addi t0, t0, -1
    bnez t0, delay

	j loop

.size	main, .-main