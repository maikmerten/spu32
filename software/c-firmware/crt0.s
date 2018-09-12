
.section .text
 
.global _start
_start:
	# reset vector at 0x0
	.=0x0
	j _init

# interrupt handler
.=0x10
_interrupt:
	# for now just do an endless loop
	j _interrupt



_init:
	# set up stack pointer
	li sp,(512 * 1024)

	# call main function
	jal ra,main

	# back to start
	j _start
