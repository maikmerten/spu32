package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 *
 * @author maik
 */
public class BootloaderProtocol {

    private final SerialConnection conn;

    public BootloaderProtocol(SerialConnection conn) {
        this.conn = conn;
    }

    private byte byteIn() throws Exception {
        InputStream is = conn.getInputStream();

        long starttime = System.currentTimeMillis();
        while (is.available() < 1) {
            //Thread.sleep(1);
            long delta = System.currentTimeMillis() - starttime;
            if (delta > 2000) {
                throw new Exception("timeout during byte read");
            }
        }

        return (byte) (is.read() & 0xFF);
    }

    private void bytesOut(byte[] bytes) throws Exception {
        OutputStream os = conn.getOutputStream();
        os.write(bytes);
    }

    private byte[] assemble32(int data) {
        byte a0 = (byte) ((data >> 24) & 0xFF);
        byte a1 = (byte) ((data >> 16) & 0xFF);
        byte a2 = (byte) ((data >> 8) & 0xFF);
        byte a3 = (byte) (data & 0xFF);

        byte[] result = {a0, a1, a2, a3};
        return result;
    }

    public void callAddress(int address) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] opcode = {'C'};
        byte[] adr = assemble32(address);
        baos.write(opcode);
        baos.write(adr);

        bytesOut(baos.toByteArray());
    }

    public void uploadWithUART(int address, byte[] data) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] opcode = {'U'};
		byte[] adr = assemble32(address);
        byte[] length = assemble32(data.length);
        baos.write(opcode);
		baos.write(adr);
        baos.write(length);
        baos.write(data);

        bytesOut(baos.toByteArray());

    }
    
    public byte[] writeToSPI(byte[] data) throws Exception {
        int datalen = data.length;
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] opcode = {'S'};
        byte[] len = assemble32(data.length);
        baos.write(opcode);
        baos.write(len);
        baos.write(data);
        bytesOut(baos.toByteArray());
        
        byte[] receivedData = new byte[datalen];
        long startTime = System.currentTimeMillis();
        while(conn.getInputStream().available() < datalen) {
            Thread.sleep(1);
            if(System.currentTimeMillis() - startTime > 500) {
                throw new Exception("timeout while waiting for SPI data...");
            }
        }
        conn.getInputStream().read(receivedData);
        return receivedData;
        
    }

}
