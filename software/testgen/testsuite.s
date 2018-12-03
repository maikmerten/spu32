#include "../asm/devices.h"

.section .text
 
.global _start

testsuite:
li sp,1024
sb zero, DEV_LED(x0) # clear LEDs

# jump to test collection
jal testcollection

# signal end of tests on LEDS
li x31,0xF0
sb x31, DEV_LED(x0) # 0xF0 on LEDs signals end of tests

#ifdef UART
# write result to UART
wait_uart:
lbu x31, DEV_UART_TX_READY(x0)
beqz x31, wait_uart
sb x5, DEV_UART_DATA(x0)
#endif

storeloop:
sb x5, DEV_LED(x0) # store lsb of test result on LEDs
j storeloop


.include "testcollection.s"
