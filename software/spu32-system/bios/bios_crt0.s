
.section .text
 
.global _start
_start:
	# reference bios_isr so it doesn't get garbage collected
	jal bios_isr

