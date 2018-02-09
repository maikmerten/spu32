.text
main:
	li t0, 0
	li t1, 512
	sw t0, 0(t1)
loop:
	lw t0, 0(t1)
	addi t0, t0, 1
	sw t0, 0(t1)

	j loop

.size	main, .-main
