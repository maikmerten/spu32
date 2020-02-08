#include "devices.h"

.section .text
 
.global _start

init_sd:
    # push SD card into SPI mode to ensure there's no SPI bus contention
    # ensure SD card is not selected
    sb zero, DEV_SPI_SELECT(zero)
    
    # transmit clock pulses for init sequence
    li s1, 50
init_sd_wakeup:
    li a0, 0xFF
    jal transmit_spi
    addi s1, s1, -1
    bnez s1, init_sd_wakeup

    # select SD card
    li a1, 2 # SD card is SPI device 2
    sb a1, DEV_SPI_SELECT(zero)
    li a0, 0xFF
    jal transmit_spi

    # transmit CMD0
    li a0, 0x40 # CMD0 (0 | 0x40)
    jal transmit_spi
     # transmit 4 zero bytes as argument
    li s1, 4
init_sd_cmd0_args:
    li a0, 0x00
    jal transmit_spi
    addi s1, s1, -1
    bnez s1, init_sd_cmd0_args
    # transmit CRC
    li a0, 0x94
    jal transmit_spi

    # receive response
    li s1, 20
init_sd_end:
    li a0, 0xFF
    jal transmit_spi
    addi s1, s1, -1
    bnez s1, init_sd_end

    # deselect SD card and send a few more clock pulses
    sb zero, DEV_SPI_SELECT(zero)
    li a0, 0xFF
    jal transmit_spi


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
    # initialize the first 4096 bytes of RAM from SPI-Flash
    li t1, 4096
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