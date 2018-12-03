#!/bin/bash
COUNTER=0;
while true; do
	COUNTER=$[COUNTER + 1]
	make clean
	make testsuite.dat
	cd ../..
	./test.sh ./cpu/tests/cpu_tb.v
	RETCODE=$?
	if [ "$RETCODE" == 0 ]; then
		echo "success, run $COUNTER"
	else
		echo "FAIL, run $COUNTER"
		exit 1
	fi

	cd ./software/testgen

done


