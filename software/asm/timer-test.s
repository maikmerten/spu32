#include "devices.h"

.section .text

.global _start

main:

loop:
    lw t1,DEV_TIMER(zero)
    srli t1,t1,10
    sb t1,DEV_LED(zero)

	j loop

.size	main, .-main