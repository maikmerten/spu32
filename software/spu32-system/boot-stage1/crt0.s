
.section .text
 
.global _start
_start:
	# reset vector at 0x0
	.=0x0

_init:
    # turn on board LEDs
    li s1, 0xFF
    sb s1, -1(zero)

	# set up stack pointer
	li s1, (512 - 40) * 1024;
	mv sp, s1

	# call main function
	jal ra,main

	# register BIOS ISR
	li s1, (512 - 32) * 1024;
	csrrw zero, 0x7C3, s1

    # turn off board LEDs
    sb zero, -1(zero)

	# jump into stage 2 bootloader
	li s1, (256 * 1024);
	jr s1

