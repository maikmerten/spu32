#!/bin/bash

# make sure the serial uploader is built
cd ../serial-uploader && make
cd ../testgen

COUNTER=0;
while true; do
	COUNTER=$[COUNTER + 1]
	make clean
	make testsuite-uart.bin

	../serial-uploader/uploader -d /dev/ttyUSB1 -f testsuite-uart.bin -t

	RETCODE=$?
	if [ "$RETCODE" == 0 ]; then
		echo "success, run $COUNTER"
	else
		echo "FAIL, run $COUNTER"
		exit 1
	fi

done


