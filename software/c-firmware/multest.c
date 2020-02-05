#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>

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

    printf("MUL passed\n\r");
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

    printf("MULH passed\n\r");
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

    printf("MULHSU passed\n\r");
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

    printf("MULHU passed\n\r");
}

int main()
{
    testMul();
    testMulh();
    testMulhsu();
    testMulhu();

    printf("Tests passed.\n\r");

    while (1)
    {
    }

    return 0;
}