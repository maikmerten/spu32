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
    lw t1, DEV_TIMER(zero)
receive_uart_wait_receive:
    lw t2, DEV_TIMER(zero)
    sub t2, t2, t1
    # timeout in milliseconds
    li t3, 3000
    # check for timeout, branch accordingly
    bgeu t2, t3, load_from_spi
    lbu t0, DEV_UART_RX_READY(zero)
    beqz t0, receive_uart_wait_receive
    lbu a0, DEV_UART_DATA(zero)
    ret

load_from_spi:
    # select SPI device (hopefully a flash storage with executable code...)
    li t0, 1
    sb t0, DEV_SPI_SELECT(zero)

    # send fast read command
    li a0, 0x0B
    jal transmit_spi

    # send address (0x0 in this case) and dummy byte for fast read
    li t0, 4
load_from_spi_send_address_and_dummy:    
    li a0, 0
    jal transmit_spi
    addi t0, t0, -1
    bnez t0, load_from_spi_send_address_and_dummy

    # read bytes from SPI flash and write to memory, starting at address 0x0
    mv t0, zero
    li t1, 1024
load_from_spi_copyloop:
    jal transmit_spi
    sb a0, 0(t0)
    addi t0, t0, 1
    bne t0, t1, load_from_spi_copyloop

    # deselect SPI device
    sb zero, DEV_SPI_SELECT(zero)
    # start execution at 0x0
    jr zero


transmit_spi:
    # wait until SPI port is ready
transmit_spi_readyloop:
    lbu a6, DEV_SPI_READY(zero)
    beqz a6, transmit_spi_readyloop
    # start transmission by writing data to SPI port
    sb a0, DEV_SPI_DATA(zero)
    # wait until SPI port is ready again (transmission finished)
transmit_spi_readyloop2:
    lbu a6, DEV_SPI_READY(zero)
    beqz a6, transmit_spi_readyloop2
    # write received data to a0 and return
    lbu a0, DEV_SPI_DATA(zero)
    ret


.size	main, .-main