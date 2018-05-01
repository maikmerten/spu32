#include "devices.h"

.section .text
 
.global _start

main:

wait_read:
    lb t2,DEV_UART_RX_READY(zero) # load receive ready status register
    beq t2,zero,wait_read

    # read received byte
    lbu t1,DEV_UART_DATA(zero)
    # write byte to LED output
    sb t1,DEV_LED(zero)

wait_write:
    lb t2,DEV_UART_TX_READY(zero) # load send ready status register
    beq t2,zero,wait_write

    # send received byte
    sb t1,DEV_UART_DATA(zero)

    j wait_read


.size	main, .-main