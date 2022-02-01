TOOLPREFIX=riscv32-unknown-elf


all: testsuite.dat

clean:
	-rm *.bin *.dat *.o testcollection.s

testcollection.s:
	java -jar tomthumb-testgen-1.0-SNAPSHOT.jar 128 > testcollection.s

testsuite.o: testcollection.s testsuite.s
	${TOOLPREFIX}-gcc -march=rv32i -mabi=ilp32 -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp -o testsuite.o testsuite.s

testsuite.bin: testsuite.o
	${TOOLPREFIX}-objcopy -O binary testsuite.o testsuite.bin
	truncate -s 8192 testsuite.bin

testsuite.dat: testsuite.bin
	hexdump -v -f hexdump-format-byte testsuite.bin > testsuite.dat

testsuite-uart.o: testcollection.s testsuite.s
	${TOOLPREFIX}-elf-gcc -march=rv32i -mabi=ilp32 -DUART -DNOLEDS -march=rv32i -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp -o testsuite-uart.o testsuite.s

testsuite-uart.bin: testsuite-uart.o
	${TOOLPREFIX}-objcopy -O binary testsuite-uart.o testsuite-uart.bin

dump:
	${TOOLPREFIX}-objdump -d testsuite.o

