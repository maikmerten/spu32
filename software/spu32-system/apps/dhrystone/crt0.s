
.section .text
 
.global _start
_start:
	# reset vector at 0x0
	.=0x0
	# call main function
	j main




