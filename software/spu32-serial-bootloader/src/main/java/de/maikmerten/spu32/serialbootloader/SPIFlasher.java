package de.maikmerten.spu32.serialbootloader;

/**
 *
 * @author maik
 */
public class SPIFlasher {
    
    private final byte CMD_CHIP_ERASE = (byte) 0x60;
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
        
        System.out.println("busy response: " + response[1]);
        
        return (response[1] & 0x01) != 0;
    }
    
    public void enableWrite() throws Exception {
        byte[] op = {CMD_WRITE_ENABLE};
        bp.writeToSPI(op);
    }
    
}
