#include "devices.h"
#include "msr.h"

.section .text
 
.global _start


main:
    li sp, 1024
    li a0, 0
    sb zero, DEV_LED(zero)
    j interrupt_setup

########## interrupt handler ############
.=16
trap:
    # push registers to stack that will be modified
    addi sp, sp, -4
    sw t0, 0(sp)

    # confirm interrupt
    lb zero, DEV_TIMER_INTERRUPT(zero)

    lbu t0, DEV_LED(zero)
    not t0, t0
    sb t0, DEV_LED(zero)

    # set up next interrupt
    lw t0, DEV_TIMER(zero)
    addi t0, t0, 500
    sw t0, DEV_TIMER_INTERRUPT(zero)

    # restore registers and return from trap handler
    lw t0, 0(sp)
    addi sp, sp, 4
    mret
##### end of interrupt handler ##########

interrupt_setup:
    # read status register
    csrrw t1, MSR_STATUS_R, zero
    # set least-significant bit (interrupt enable)
    ori t1, t1, 1
    # write back to status register
    csrrw zero, MSR_STATUS_RW, t1

    # set up timer interrupt in one second
    lw t1, DEV_TIMER(zero)
    addi t1, t1, 500
    sw t1, DEV_TIMER_INTERRUPT(zero)

loop:
	j loop

.size	main, .-main