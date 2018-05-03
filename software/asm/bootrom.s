#include "devices.h"

.section .text
 
.global _start

main:
    jal receive_uart
    # check for "U" (load from UART)
    li t0, 0x55
    beq a0, t0, load_from_uart

    # check for "C" (call memory address)
    li t0, 0x43
    beq a0, t0, call


    j main


call:
    jal receive_uart_4_bytes
    jalr a0
    j main


load_from_uart:
    # receive start address
    jal receive_uart_4_bytes
    mv s0, a0
    # receive number of bytes
    jal receive_uart_4_bytes
    mv s1, a0
    # init byte counter
    mv s2, zero
load_from_uart_receive_bytes:
    # back to main if specified number of bytes received
    bgeu s2, s1, main
    # get a byte
    jal receive_uart
    # compute address and store byte
    add t0, s0, s2
    sb a0, 0(t0)
    # increment counter
    addi s2, s2, 1
    j load_from_uart_receive_bytes
 


receive_uart_4_bytes:
    mv t6, ra
    jal receive_uart
    slli t5, a0, 8
    jal receive_uart
    or t5, t5, a0
    slli t5, t5, 8
    jal receive_uart
    or t5, t5, a0
    slli t5, t5, 8
    jal receive_uart
    or a0, t5, a0
    mv ra, t6
    ret


transmit_uart:
    lbu t0, DEV_UART_TX_READY(zero)
    beqz t0, transmit_uart
    sb a0, DEV_UART_DATA(zero)
    ret

receive_uart:
    lw t1, DEV_TIMER(zero)
receive_uart_wait_receive:
    lw t2, DEV_TIMER(zero)
    sub t2, t2, t1
    li t3, 500                      # 500 ms timeout
    bgeu t2, t3, timeout            # timeout detected
    lbu t0, DEV_UART_RX_READY(zero)
    beqz t0, receive_uart_wait_receive
    lbu a0, DEV_UART_DATA(zero)
    ret

timeout:
    lbu t0, DEV_TIMER(zero)
    sb t0, DEV_LED(zero)
    j main


.size	main, .-main