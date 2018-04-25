package de.maikmerten.spu32.emu.tests;

import de.maikmerten.spu32.emu.cpu.CPU;
import org.testng.Assert;
import org.testng.annotations.Test;

/**
 *
 * @author maik
 */
public class TestCPU {

    CPU cpu;

    public TestCPU() {
    }

    @Test
    public void testImmediateDecoding() {

        int instruction, result;

        instruction = 0x00f00313; // addi t1,x0,15
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, 15);

        instruction = 0x01c02283; // lw t0,28(x0)
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, 28);

        instruction = 0xe0502023; // sw t0,-512(x0)
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, -512);

        instruction = 0xff1ff3ef; // jal x7,4 (from 0x14)
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, -16);

        instruction = 0xf0f0f2b7; // lui t0,0xf0f0f
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, 0xf0f0f000);

        instruction = 0xfe7316e3; // bne t1,t2,4 (from 0x18)
        result = cpu.testImmediateDecode(instruction);
        Assert.assertEquals(result, -20);

    }

    @org.testng.annotations.BeforeClass
    public static void setUpClass() throws Exception {
    }

    @org.testng.annotations.AfterClass
    public static void tearDownClass() throws Exception {
    }

    @org.testng.annotations.BeforeMethod
    public void setUpMethod() throws Exception {
        this.cpu = new CPU(null, 0x0, 0x10);
    }

    @org.testng.annotations.AfterMethod
    public void tearDownMethod() throws Exception {
    }
}
