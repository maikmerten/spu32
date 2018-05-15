#include "devices.h"

.section .text
 
.global _start

#define CMD_CHIP_ERASE 0x60
#define CMD_PAGE_PROGRAM 0x02
#define CMD_READ_STATUS 0x05
#define CMD_WRITE_ENABLE 0x06


main:
    # init stack pointer
    li sp, 4096
    # init global pointer
    li sp, 2048

main_timeout:
    jal deselect_spi
    # transmit "#"-character to signal ready
    li a0, 35
    jal transmit_uart

main_loop:

    jal receive_uart
    jal transmit_uart
    jal flash_erase_chip

    j main_loop

flash_enable_write:
    addi sp, sp, -4
    sw ra, 0(sp)

    jal select_spi
    li a0, CMD_WRITE_ENABLE
    jal transmit_spi
    jal deselect_spi

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# send chip erase command
flash_erase_chip:
    addi sp, sp, -4
    sw ra, 0(sp)

    jal flash_enable_write

    jal select_spi
    li a0, CMD_CHIP_ERASE
    jal transmit_spi
    jal deselect_spi

    jal flash_ensure_ready

    lw ra, 0(sp)
    addi sp, sp, 4
    ret


# wait until SPI flash device is not busy
flash_ensure_ready:
    addi sp, sp, -8
    sw ra, 0(sp)
    sw s0, 4(sp)

flash_ensure_ready_loop:
    jal select_spi
    li a0, CMD_READ_STATUS
    # send op
    jal transmit_spi
    # send dummy
    jal transmit_spi
    andi s0, a0, 0x01
    jal deselect_spi
    bnez s0, flash_ensure_ready_loop

    lw s0, 4(sp)
    lw ra, 0(sp)
    addi sp, sp, 8
    ret


# transmit byte stored in a0 via serial port
transmit_uart:
    addi sp, sp, -4
    sw s0, 0(sp)

transmit_uart_readyloop:
    lbu s0, DEV_UART_TX_READY(zero)
    beqz s0, transmit_uart_readyloop
    sb a0, DEV_UART_DATA(zero)

    lw s0, 0(sp)
    addi sp, sp, 4
    ret

# try to receive a byte. Can time out
receive_uart:
    addi sp, sp, -12
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)

    lw s0, DEV_TIMER(zero)
receive_uart_wait_receive:
    lw s1, DEV_TIMER(zero)
    sub s1, s1, s0
    # timeout in milliseconds
    li s2, 3000
    # check for timeout, branch accordingly
    bgeu s1, s2, main_timeout
    lbu s1, DEV_UART_RX_READY(zero)
    beqz s1, receive_uart_wait_receive
    lbu a0, DEV_UART_DATA(zero)

    lw s2, 8(sp)
    lw s1, 4(sp)
    lw s0, 0(sp)
    addi sp, sp, 12
    ret

# select SPI device
select_spi:
    li t0, 1
    sb t0, DEV_SPI_SELECT(zero)
    ret

# deselect SPI device
deselect_spi:
    sb zero, DEV_SPI_SELECT(zero)
    ret

# transmit and receive byte via SPI port
transmit_spi:
    addi sp, sp, -4
    sw s0, 0(sp)

    # wait until SPI port is ready
transmit_spi_readyloop:
    lbu s0, DEV_SPI_READY(zero)
    beqz s0, transmit_spi_readyloop
    # start transmission by writing data to SPI port
    sb a0, DEV_SPI_DATA(zero)
    # wait until SPI port is ready again (transmission finished)
transmit_spi_readyloop2:
    lbu s0, DEV_SPI_READY(zero)
    beqz s0, transmit_spi_readyloop2
    # write received data to a0 and return
    lbu a0, DEV_SPI_DATA(zero)

    lw s0, 0(sp)
    addi sp, sp, 4
    ret

.size	main, .-main