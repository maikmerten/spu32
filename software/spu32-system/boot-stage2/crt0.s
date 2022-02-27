
.section .text._start
 
.global _start
_start:
	#.=0x0

	# call main function
	jal ra,main


	# start execution of shell
	li t0, (512 - 36) * 1024;
	jr t0

