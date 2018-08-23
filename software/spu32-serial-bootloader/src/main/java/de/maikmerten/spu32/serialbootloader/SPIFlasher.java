package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;

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
    
    private final int CHUNKSHIFT = 5;
    private final int CHUNKSIZE = 32;

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
        if(data.length != CHUNKSIZE) {
            throw new IllegalArgumentException("chunk programming requires " + CHUNKSIZE + " bytes of data");
        }
        byte[] op = {CMD_PAGE_PROGRAM};
        byte[] addr = addr24(chunknum << CHUNKSHIFT);
        
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(op);
        baos.write(addr);
        baos.write(data);
        bp.writeToSPI(baos.toByteArray());
        
    }
    
    public byte[] readChunk(int chunknum) throws Exception {
        byte[] result = new byte[CHUNKSIZE];
        
        byte[] op = {CMD_FASTREAD};
        byte[] addr = addr24(chunknum << CHUNKSHIFT);
        
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(op);
        baos.write(addr);
        baos.write(op); // dummy byte
        baos.write(result); // dummy bytes
        
        byte[] received = bp.writeToSPI(baos.toByteArray());
        
        int idx = 0;
        for(int i = 5; i < received.length; ++i) {
            result[idx++] = received[i];
        }
        
        return result;
    }
    
    private void clearBuffer(byte[] buf) {
        for(int i = 0; i < buf.length; ++i) {
            buf[i] = (byte) 0xFF;
        }
    }
    
    public void programFile(File f) throws Exception {
        FileInputStream fis = new FileInputStream(f);
        System.out.print("erasing chip...");
        enableWrite();
        eraseChip();
        while(isBusy()) {
            System.out.print(".");
        }
        System.out.println();
        
        byte[] buf = new byte[CHUNKSIZE];
        clearBuffer(buf);
        int chunk = 0;
        int read = fis.read(buf);
        while(read > 0) {
            // write chunk to SPI flash
            System.out.print("writing chunk " + chunk + " ");
            enableWrite();
            programChunk(chunk, buf);
            while(isBusy()) {
                System.out.print(".");
            }
            System.out.println();
            
            // read chunk back and compare
            byte[] chunkData = readChunk(chunk);
            for(int i = 0; i < buf.length; ++i) {
                if(chunkData[i] != buf[i]) {
                    throw new Exception("read chunk data does not match!");
                }
            }
            
            // clear buffer and read more data
            clearBuffer(buf);
            read = fis.read(buf);
            chunk++;
            
        }
        
    }
    
}
