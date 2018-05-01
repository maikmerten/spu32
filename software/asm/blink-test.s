#include "devices.h"

.section .text
 
.global _start

main:
    li t0,0

loop:
    addi t0,t0,1
    srli t1,t0,16
    sb t1,DEV_LED(zero)

	j loop

.size	main, .-main