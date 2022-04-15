// This test program uses test vectors taken from "risc-v compliance."
// "risc-compliance" is licensed as follows:
/*
# Copyright (c) 2018, Imperas Software Ltd.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#      * Redistributions of source code must retain the above copyright
#        notice, this list of conditions and the following disclaimer.
#      * Redistributions in binary form must reproduce the above copyright
#        notice, this list of conditions and the following disclaimer in the
#        documentation and/or other materials provided with the distribution.
#      * Neither the name of the Imperas Software Ltd. nor the
#        names of its contributors may be used to endorse or promote products
#        derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Imperas Software Ltd. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>

#include "../../bios/devices.h"

#define LED *((volatile uint8_t*) DEV_LED)

void mul(uint32_t expected, uint32_t s1, uint32_t s2)
{
    uint32_t result;
    asm("mul %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("mul fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void mulh(int32_t expected, int32_t s1, int32_t s2)
{
    int32_t result;
    asm("mulh %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("mulh fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void mulhsu(int32_t expected, int32_t s1, uint32_t s2)
{
    int32_t result;
    asm("mulhsu %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("mulhsu fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void mulhu(uint32_t expected, uint32_t s1, uint32_t s2)
{
    uint32_t result;
    asm("mulhu %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("mulhu fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void div(int32_t expected, int32_t s1, int32_t s2)
{
    int32_t result;
    asm("div %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("div fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void divu(uint32_t expected, uint32_t s1, uint32_t s2)
{
    uint32_t result;
    asm("divu %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("divu fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void rem(int32_t expected, int32_t s1, int32_t s2)
{
    int32_t result;
    asm("rem %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("rem fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void remu(uint32_t expected, uint32_t s1, uint32_t s2)
{
    uint32_t result;
    asm("remu %[dest], %[reg1], %[reg2]"
        : [dest] "=r"(result)
        : [reg1] "r"(s1), [reg2] "r"(s2));
    if (result != expected)
    {
        printf("remu fail: %d %d %d but got %d\n\r", expected, s1, s2, result);
        while (1)
        {
        }
    }
}

void testMul()
{
    // test values from riscv-compliance, MUL.S

    mul(0, 0x0, 0x0);
    mul(0, 0x0, 0x1);
    mul(0, 0x0, -0x1);
    mul(0, 0x0, 0x7fffffff);
    mul(0, 0x0, 0x80000000);

    mul(0, 0x1, 0x0);
    mul(0x1, 0x1, 0x1);
    mul(0xffffffff, 0x1, -0x1);
    mul(0x7fffffff, 0x1, 0x7fffffff);
    mul(0x80000000, 0x1, 0x80000000);

    mul(0, -0x1, 0x0);
    mul(0xffffffff, -0x1, 0x1);
    mul(0x1, -0x1, -0x1);
    mul(0x80000001, -0x1, 0x7fffffff);
    mul(0x80000000, -0x1, 0x80000000);

    mul(0, 0x7fffffff, 0x0);
    mul(0x7fffffff, 0x7fffffff, 0x1);
    mul(0x80000001, 0x7fffffff, -0x1);
    mul(0x1, 0x7fffffff, 0x7fffffff);
    mul(0x80000000, 0x7fffffff, 0x80000000);

    mul(0, 0x80000000, 0x0);
    mul(0x80000000, 0x80000000, 0x1);
    mul(0x80000000, 0x80000000, -0x1);
    mul(0x80000000, 0x80000000, 0x7fffffff);
    mul(0, 0x80000000, 0x80000000);

    //printf("MUL passed\n\r");
}

void testMulh()
{
    // test values from riscv-compliance, MULH.S

    mulh(0, 0x0, 0x0);
    mulh(0, 0x0, 0x1);
    mulh(0, 0x0, -0x1);
    mulh(0, 0x0, 0x7fffffff);
    mulh(0, 0x0, 0x80000000);

    mulh(0, 0x1, 0x0);
    mulh(0, 0x1, 0x1);
    mulh(0xffffffff, 0x1, -0x1);
    mulh(0, 0x1, 0x7fffffff);
    mulh(0xffffffff, 0x1, 0x80000000);

    mulh(0, -0x1, 0x0);
    mulh(0xffffffff, -0x1, 0x1);
    mulh(0, -0x1, -0x1);
    mulh(0xffffffff, -0x1, 0x7fffffff);
    mulh(0, -0x1, 0x80000000);

    mulh(0, 0x7fffffff, 0x0);
    mulh(0, 0x7fffffff, 0x1);
    mulh(0xffffffff, 0x7fffffff, -0x1);
    mulh(0x3fffffff, 0x7fffffff, 0x7fffffff);
    mulh(0xc0000000, 0x7fffffff, 0x80000000);

    mulh(0, 0x80000000, 0x0);
    mulh(0xffffffff, 0x80000000, 0x1);
    mulh(0, 0x80000000, -0x1);
    mulh(0xc0000000, 0x80000000, 0x7fffffff);
    mulh(0x40000000, 0x80000000, 0x80000000);

    //printf("MULH passed\n\r");
}

void testMulhsu()
{
    // test values from riscv-compliance, MULHSU.S

    mulhsu(0, 0x0, 0x0);
    mulhsu(0, 0x0, 0x1);
    mulhsu(0, 0x0, -0x1);
    mulhsu(0, 0x0, 0x7fffffff);
    mulhsu(0, 0x0, 0x80000000);

    mulhsu(0, 0x1, 0x0);
    mulhsu(0, 0x1, 0x1);
    mulhsu(0, 0x1, -0x1);
    mulhsu(0, 0x1, 0x7fffffff);
    mulhsu(0, 0x1, 0x80000000);

    mulhsu(0, -0x1, 0x0);
    mulhsu(0xffffffff, -0x1, 0x1);
    mulhsu(0xffffffff, -0x1, -0x1);
    mulhsu(0xffffffff, -0x1, 0x7fffffff);
    mulhsu(0xffffffff, -0x1, 0x80000000);

    mulhsu(0, 0x7fffffff, 0x0);
    mulhsu(0, 0x7fffffff, 0x1);
    mulhsu(0x7ffffffe, 0x7fffffff, -0x1);
    mulhsu(0x3fffffff, 0x7fffffff, 0x7fffffff);
    mulhsu(0x3fffffff, 0x7fffffff, 0x80000000);

    mulhsu(0, 0x80000000, 0x0);
    mulhsu(0xffffffff, 0x80000000, 0x1);
    mulhsu(0x80000000, 0x80000000, -0x1);
    mulhsu(0xc0000000, 0x80000000, 0x7fffffff);
    mulhsu(0xc0000000, 0x80000000, 0x80000000);

    //printf("MULHSU passed\n\r");
}

void testMulhu()
{
    // test values from riscv-compliance, MULHU.S

    mulhu(0, 0x0, 0x0);
    mulhu(0, 0x0, 0x1);
    mulhu(0, 0x0, -0x1);
    mulhu(0, 0x0, 0x7fffffff);
    mulhu(0, 0x0, 0x80000000);

    mulhu(0, 0x1, 0x0);
    mulhu(0, 0x1, 0x1);
    mulhu(0, 0x1, -0x1);
    mulhu(0, 0x1, 0x7fffffff);
    mulhu(0, 0x1, 0x80000000);

    mulhu(0, -0x1, 0x0);
    mulhu(0, -0x1, 0x1);
    mulhu(0xfffffffe, -0x1, -0x1);
    mulhu(0x7ffffffe, -0x1, 0x7fffffff);
    mulhu(0x7fffffff, -0x1, 0x80000000);

    mulhu(0, 0x7fffffff, 0x0);
    mulhu(0, 0x7fffffff, 0x1);
    mulhu(0x7ffffffe, 0x7fffffff, -0x1);
    mulhu(0x3fffffff, 0x7fffffff, 0x7fffffff);
    mulhu(0x3fffffff, 0x7fffffff, 0x80000000);

    mulhu(0, 0x80000000, 0x0);
    mulhu(0, 0x80000000, 0x1);
    mulhu(0x7fffffff, 0x80000000, -0x1);
    mulhu(0x3fffffff, 0x80000000, 0x7fffffff);
    mulhu(0x40000000, 0x80000000, 0x80000000);

    //printf("MULHU passed\n\r");
}

void testDiv()
{
    // test values from riscv-compliance, DIV.S

    div(0xffffffff, 0x0, 0x0);
    div(0, 0x0, 0x1);
    div(0, 0x0, -0x1);
    div(0, 0x0, 0x7fffffff);
    div(0, 0x0, 0x80000000);

    div(0xffffffff, 0x1, 0x0);
    div(0x1, 0x1, 0x1);
    div(0xffffffff, 0x1, -0x1);
    div(0, 0x1, 0x7fffffff);
    div(0, 0x1, 0x80000000);

    div(0xffffffff, -0x1, 0x0);
    div(0xffffffff, -0x1, 0x1);
    div(0x1, -0x1, -0x1);
    div(0, -0x1, 0x7fffffff);
    div(0, -0x1, 0x80000000);

    div(0xffffffff, 0x7fffffff, 0x0);
    div(0x7fffffff, 0x7fffffff, 0x1);
    div(0x80000001, 0x7fffffff, -0x1);
    div(0x1, 0x7fffffff, 0x7fffffff);
    div(0, 0x7fffffff, 0x80000000);

    div(0xffffffff, 0x80000000, 0x0);
    div(0x80000000, 0x80000000, 0x1);
    div(0x80000000, 0x80000000, -0x1);
    div(0xffffffff, 0x80000000, 0x7fffffff);
    div(0x1, 0x80000000, 0x80000000);
    
    //printf("DIV passed\n\r");
}

void testDivu()
{
    // test values from riscv-compliance, DIVU.S

    divu(0xffffffff, 0x0, 0x0);
	divu(0, 0x0, 0x1);
	divu(0, 0x0, -0x1);
	divu(0, 0x0, 0x7fffffff);
	divu(0, 0x0, 0x80000000);

    divu(0xffffffff, 0x1, 0x0);
	divu(0x1, 0x1, 0x1);
	divu(0, 0x1, -0x1);
	divu(0, 0x1, 0x7fffffff);
	divu(0, 0x1, 0x80000000);

    divu(0xffffffff, -0x1, 0x0);
	divu(0xffffffff, -0x1, 0x1);
	divu(0x1, -0x1, -0x1);
	divu(0x2, -0x1, 0x7fffffff);
	divu(0x1, -0x1, 0x80000000);

	divu(0xffffffff, 0x7fffffff, 0x0);
	divu(0x7fffffff, 0x7fffffff, 0x1);
	divu(0, 0x7fffffff, -0x1);
	divu(0x1, 0x7fffffff, 0x7fffffff);
	divu(0, 0x7fffffff, 0x80000000);

	divu(0xffffffff, 0x80000000, 0x0);
	divu(0x80000000, 0x80000000, 0x1);
	divu(0, 0x80000000, -0x1);
	divu(0x1, 0x80000000, 0x7fffffff);
	divu(0x1, 0x80000000, 0x80000000);

    //printf("DIVU passed\n\r");
}

void testRem()
{
    // test values from riscv-compliance, REM.S

    rem(0, 0x0, 0x0);
	rem(0, 0x0, 0x1);
	rem(0, 0x0, -0x1);
	rem(0, 0x0, 0x7fffffff);
	rem(0, 0x0, 0x80000000);

    rem(0x1, 0x1, 0x0);
	rem(0, 0x1, 0x1);
	rem(0, 0x1, -0x1);
	rem(0x1, 0x1, 0x7fffffff);
	rem(0x1, 0x1, 0x80000000);

    rem(0xffffffff, -0x1, 0x0);
	rem(0, -0x1, 0x1);
	rem(0, -0x1, -0x1);
	rem(0xffffffff, -0x1, 0x7fffffff);
	rem(0xffffffff, -0x1, 0x80000000);

    rem(0x7fffffff, 0x7fffffff, 0x0);
	rem(0, 0x7fffffff, 0x1);
	rem(0, 0x7fffffff, -0x1);
	rem(0, 0x7fffffff, 0x7fffffff);
	rem(0x7fffffff, 0x7fffffff, 0x80000000);

    rem(0x80000000, 0x80000000, 0x0);
	rem(0, 0x80000000, 0x1);
	rem(0, 0x80000000, -0x1);
	rem(0xffffffff, 0x80000000, 0x7fffffff);
	rem(0, 0x80000000, 0x80000000);
    
    //printf("REM passed\n\r");
}

void testRemu()
{
    // test values from riscv-compliance, REMU.S

    remu(0, 0x0, 0x0);
	remu(0, 0x0, 0x1);
	remu(0, 0x0, -0x1);
	remu(0, 0x0, 0x7fffffff);
	remu(0, 0x0, 0x80000000);

    remu(0x1, 0x1, 0x0);
	remu(0, 0x1, 0x1);
	remu(0x1, 0x1, -0x1);
	remu(0x1, 0x1, 0x7fffffff);
	remu(0x1, 0x1, 0x80000000);

    remu(0xffffffff, -0x1, 0x0);
	remu(0, -0x1, 0x1);
	remu(0, -0x1, -0x1);
	remu(0x1, -0x1, 0x7fffffff);
	remu(0x7fffffff, -0x1, 0x80000000);

    remu(0x7fffffff, 0x7fffffff, 0x0);
	remu(0, 0x7fffffff, 0x1);
	remu(0x7fffffff, 0x7fffffff, -0x1);
	remu(0, 0x7fffffff, 0x7fffffff);
	remu(0x7fffffff, 0x7fffffff, 0x80000000);

    remu(0x80000000, 0x80000000, 0x0);
	remu(0, 0x80000000, 0x1);
	remu(0x80000000, 0x80000000, -0x1);
	remu(0x1, 0x80000000, 0x7fffffff);
	remu(0, 0x80000000, 0x80000000);
    
    //printf("REMU passed\n\r");
}

void doTests() {
    uint32_t repeats = 5000;

    printf("Doing round of %d repeats...\n\r", repeats);
    while(repeats--) {
        testMul();
        testMulh();
        testMulhsu();
        testMulhu();
        testDiv();
        testDivu();
        testRem();
        testRemu();
    }
    printf("Tests passed.\n\r");
}


int main()
{
    uint32_t round = 0;
    while(1) {
        LED = (uint8_t)round;
        printf("\n\r\n\r-- Test round %d --\n\r", ++round);
        doTests();

        
    }

    return 0;
}