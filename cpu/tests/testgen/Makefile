
all: testsuite.dat

clean:
	-rm *.bin *.dat *.o testcollection.s

testcollection.s:
	java -jar tomthumb-testgen-1.0-SNAPSHOT.jar > testcollection.s

testsuite.o: testcollection.s testsuite.s
	riscv32-unknown-elf-gcc -march=RV32I -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp -o testsuite.o testsuite.s

testsuite.bin: testsuite.o
	riscv32-unknown-elf-objcopy -O binary testsuite.o testsuite.bin
	truncate -s 1024 testsuite.bin

testsuite.dat: testsuite.bin
	hexdump -v -f hexdump-format-byte testsuite.bin > testsuite.dat

dump:
	riscv32-unknown-elf-objdump -d testsuite.o

