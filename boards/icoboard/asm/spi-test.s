#include "devices.h"

.section .text
 
.global _start

#define SPI_OP_READ 0x03

main:
	jal chipdeselect
    jal chipselect

    # send read opcode
    li a0, SPI_OP_READ
    jal transmit

    # write three address bytes
    li a0, 0
    jal transmit
    li a0, 0
    jal transmit
    li a0, 0
    jal transmit


    li t1, 0
main_readloop:
    li a0, 0
    jal transmit

    # push read value to LEDs
    sb a0, DEV_LED(zero)
    
    # delay
    li a0, 16384
main_delay:
    addi a0, a0, -1
    bnez a0, main_delay

    j main_readloop


chipselect:
    li a6, 1
    sb a6, DEV_SPI_SELECT(zero)
    ret

chipdeselect:
    sb zero, DEV_SPI_SELECT(zero)
    ret


transmit:
    # wait until SPI port is ready
transmit_readyloop:
    lbu a6, DEV_SPI_READY(zero)
    beqz a6, transmit_readyloop

    # start transmission by writing data to SPI port
    sb a0, DEV_SPI_DATA(zero)

    # wait until SPI port is ready again (transmission finished)
transmit_readyloop2:
    lbu a6, DEV_SPI_READY(zero)
    beqz a6, transmit_readyloop2

    # write received data to a0 and return
    lbu a0, DEV_SPI_DATA(zero)
    ret



.size	main, .-main
