.section .text
 
.global _start

testsuite:
li sp,1024
sb zero,-1(x0) # clear LEDs (write to 0xFFFFFFFF)

# jump to test collection
jal testcollection

# signal end of tests on LEDS
li x31,0xF0
sb x31,-1(x0) # 0xF0 on LEDs signals end of tests

storeloop:
sb x5,-1(x0) # store lsb of test result on LEDs
j storeloop


.include "testcollection.s"
