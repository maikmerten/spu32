#include "devices.h"

.section .text
 
.global _start


main:
    li t0, 1
    sb t0, DEV_LED(zero)
    jal receive_uart
    sb zero, DEV_LED(zero)
    # check for "U" (load from UART)
    li t0, 0x55
    beq a0, t0, load_from_uart

    # check for "C" (call memory address)
    li t0, 0x43
    beq a0, t0, call



call:
    jal a1, receive_uart_4_bytes
    jalr a0
    j main


load_from_uart:
    # receive start address
    jal a1, receive_uart_4_bytes
    mv s0, a0
    # receive number of bytes
    jal a1, receive_uart_4_bytes
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


 

# NOTE: Expects return address in a1!
receive_uart_4_bytes:
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
    # return from address given in a1
    jalr zero, 0(a1)


transmit_uart:
    lbu t0, DEV_UART_TX_READY(zero)
    beqz t0, transmit_uart
    sb a0, DEV_UART_DATA(zero)
    ret

receive_uart:
    lbu t0, DEV_UART_RX_READY(zero)
    beqz t0, receive_uart
    lbu a0, DEV_UART_DATA(zero)
    ret



.size	main, .-main