.section .text
 
.global _start

testsuite:
li sp,1024
jal testcollection

storeloop:
sb x5,-1(x0) # store lsb of test result at 0xFFFFFFFF
j storeloop


.include "testcollection.s"
