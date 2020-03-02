
.section .text._start
 
.global _start
_start:
	#.=0x0

	# call main function
	jal ra,main


	# start execution of loaded program at 0x0
	jr zero

