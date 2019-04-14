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

    # check for "S" (UART to SPI)
    li t0, 0x53
    beq a0, t0, uart_to_spi

    # check for "T" (UART communications test)
    li t0, 0x54
    beq a0, t0, test_uart

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

uart_to_spi:
    # select SPI device
    li t0, 1
    sb t0, DEV_SPI_SELECT(zero)
    # receive number of bytes to be exchanged
    jal a1, receive_uart_4_bytes
    mv s0, a0
    mv s1, zero
uart_to_spi_loop:
    bgeu s1, s0, uart_to_spi_exit
    # receive byte from UART
    jal receive_uart
    # push received byte to SPI device
    jal transmit_spi
    # push byte received from SPI to UART
    jal transmit_uart
    # increment counter
    addi s1, s1, 1
    j uart_to_spi_loop

uart_to_spi_exit:
    # deselect SPI device
    sb zero, DEV_SPI_SELECT(zero)
    j main

 

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
    li t3, 500
    # check for timeout, branch accordingly
    bgeu t2, t3, load_from_spi
    lbu t0, DEV_UART_RX_READY(zero)
    beqz t0, receive_uart_wait_receive
    lbu a0, DEV_UART_DATA(zero)
    ret


test_uart:
    # receive sum of all bytes
    jal a1, receive_uart_4_bytes
    mv s0, a0
    # receive number of bytes
    jal a1, receive_uart_4_bytes
    mv s1, a0
    # init byte-counter to zero
    mv s2, zero
    # set sum to zero
    mv s3, zero
test_uart_receive_bytes:
    # back to main if specified number of bytes received
    bgeu s2, s1, test_uart_check_sum
    # get a byte
    jal receive_uart
    # add received byte to total sum
    add s3, s3, a0
    # increment counter
    addi s2, s2, 1
    j test_uart_receive_bytes
test_uart_check_sum:
    beq s3, s0, test_uart_pass
test_uart_fail:
    li a0, 0xFF
    sb a0, DEV_LED(zero)
    j test_uart_fail
test_uart_pass:
    li a0, 0x01
    sb a0, DEV_LED(zero)
    j test_uart_pass


# detect memory size, result is in t1 (load_from_spi expects it there)
detect_memory_size:
    li t1, 4096         # first assume 4K of memory
    lbu t2, 0(zero)     # load value at address zero
    neg t2, t2          # invert value
    andi t2, t2, 255    # zero out topmost 24 bits
detect_memory_size_loop:
    sb t2, 0(t1)        # store value at suspected wraparound
    lbu t3, 0(zero)     # read value at address zero... has it changed?
    beq t2, t3, detect_memory_size_end
    addi t1, t1, 1024
    j detect_memory_size_loop
detect_memory_size_end:
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
    # detect memory size, result is in t1
    jal detect_memory_size
load_from_spi_copyloop:
    # the following is a partial copy of transmit_spi
    # for performance reasons, we want a tight loop here
    # in case size ever becomes a concern, use a jal transmit_spi instead
    sb zero, DEV_SPI_DATA(zero) # write dummy bits to receive data
load_from_spi_copyloop2:
    lbu t2, DEV_SPI_READY(zero)
    beqz t2, load_from_spi_copyloop2
    # read byte via SPI, write to memory location
    lbu a0, DEV_SPI_DATA(zero)
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