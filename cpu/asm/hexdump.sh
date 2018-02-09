#/bin/bash
hexdump -v -f hexdump-format-byte $1 > $1.dat
printf "wrote $1.dat\n"
