package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayOutputStream;

/**
 *
 * @author maik
 */
public class SPIFlasher {
    
    private final byte CMD_CHIP_ERASE = (byte) 0x60;
    private final byte CMD_FASTREAD = (byte) 0x0B;
    private final byte CMD_PAGE_PROGRAM = (byte) 0x02;
    private final byte CMD_READ_STATUS = (byte) 0x05;
    private final byte CMD_WRITE_ENABLE = (byte) 0x06;

    private final BootloaderProtocol bp;
    
    public SPIFlasher(BootloaderProtocol bp) {
        this.bp = bp;
    }
    
    public void eraseChip() throws Exception {
        byte[] op = {CMD_CHIP_ERASE};
        bp.writeToSPI(op);
    }
    
    public boolean isBusy() throws Exception {
        // op and one dummy byte
        byte[] op = {CMD_READ_STATUS, CMD_READ_STATUS};
        byte[] response = bp.writeToSPI(op);
        
        return (response[1] & 0x01) != 0;
    }
    
    public void enableWrite() throws Exception {
        byte[] op = {CMD_WRITE_ENABLE};
        bp.writeToSPI(op);
    }
    
    private byte[] addr24(int addr) {
        byte b0 = (byte)((addr >> 16) & 0xFF);
        byte b1 = (byte)((addr >> 8) & 0xFF);
        byte b2 = (byte)(addr & 0xFF);
        byte[] result = {b0, b1, b2};
        return result;
    }
    
    public void programChunk(int chunknum, byte[] data) throws Exception {
        if(data.length != 64) {
            throw new IllegalArgumentException("chunk programming requires 64 bytes of data");
        }
        byte[] op = {CMD_PAGE_PROGRAM};
        byte[] addr = addr24(chunknum << 6);
        
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(op);
        baos.write(addr);
        baos.write(data);
        bp.writeToSPI(baos.toByteArray());
        
    }
    
    public byte[] readChunk(int chunknum) throws Exception {
        byte[] result = new byte[64];
        
        byte[] op = {CMD_FASTREAD};
        byte[] addr = addr24(chunknum << 6);
        
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(op);
        baos.write(addr);
        baos.write(op); // dummy byte
        baos.write(result); // 64 dummy bytes
        
        byte[] received = bp.writeToSPI(baos.toByteArray());
        
        int idx = 0;
        for(int i = 5; i < received.length; ++i) {
            result[idx++] = received[i];
        }
        
        return result;
    }
    
}
