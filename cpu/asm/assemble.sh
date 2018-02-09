#!/bin/bash
LINK="riscv32-unknown-elf-gcc -march=RV32IXcustom -O0 -nostdlib -nostartfiles -Tlink.ld -x assembler-with-cpp"
DUMP="riscv32-unknown-elf-objdump"
COPY="riscv32-unknown-elf-objcopy"

$LINK -o $1 $1.s && $DUMP -d $1 && $COPY -O binary $1 $1.bin
