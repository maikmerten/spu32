.section .text
 
.global _start

main:
    li t0,0xF0000000

wait_read:
    lb t2,1(t0) # load receive ready status register
    beq t2,zero,wait_read

    # read received byte
    lbu t1,0(t0)
    # write byte to LED output
    sb t1,-1(zero)

wait_write:
    lb t2,2(t0) # load send ready status register
    beq t2,zero,wait_write

    # send received byte
    sb t1,0(t0)

    j wait_read


.size	main, .-main