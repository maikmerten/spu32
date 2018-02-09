#!/bin/bash
echo $1
iverilog -o /tmp/iverilog-tb $1 && vvp /tmp/iverilog-tb -lxt2
RCODE=$?
echo "returning with code $RCODE"
(exit $RCODE)
