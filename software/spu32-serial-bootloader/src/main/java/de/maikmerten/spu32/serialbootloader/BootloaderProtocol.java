package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class BootloaderProtocol {

    private final SerialConnection conn;

    public BootloaderProtocol(SerialConnection conn) {
        this.conn = conn;
    }
    
    public void signalReset() throws Exception{
        // RTS line is used to trigger reset
        conn.setRTS(true);
        // wait a bit
        Thread.sleep(50);
        // clear RTS signal
        conn.setRTS(false);
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
    
    public void uploadFile(int address, File f) throws Exception {
        FileInputStream fis = new FileInputStream(f);
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buf = new byte[512];
        int read = fis.read(buf);
        while(read != -1) {
            baos.write(buf, 0, read);
            read = fis.read(buf);
        }
        uploadWithUART(address, baos.toByteArray());
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
        final int datalen = data.length;

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] opcode = {'S'};
        byte[] len = assemble32(data.length);
        baos.write(opcode);
        baos.write(len);
        baos.write(data);
        //bytesOut(baos.toByteArray());
        ByteArrayInputStream bais = new ByteArrayInputStream(baos.toByteArray());
        byte[] buf = new byte[32];

        InputReadThread t = new InputReadThread(conn.getInputStream(), datalen);
        t.start();

        int read = bais.read(buf);
        while (read > 0) {
            conn.getOutputStream().write(buf, 0, read);
            read = bais.read(buf);
        }

        t.join();

        if (t.receivedData.length != datalen) {
            throw new Exception("did not receive proper number of SPI bytes...");
        }

        return t.receivedData;

    }

    private class InputReadThread extends Thread {

        private final InputStream is;
        private final int target;
        public byte[] receivedData;

        InputReadThread(InputStream is, int target) {
            this.is = is;
            this.target = target;
        }

        @Override
        public void run() {
            try {
                ByteArrayOutputStream baos = new ByteArrayOutputStream();
                byte[] buf = new byte[64];
                int totalRead = 0;
                int read = is.read(buf);
                long start = System.currentTimeMillis();
                while (read != -1) {
                    totalRead += read;
                    baos.write(buf, 0, read);
                    if (totalRead == target) {
                        break;
                    }
                    if (read > 0) {
                        start = System.currentTimeMillis();
                    }

                    if (System.currentTimeMillis() - start > 500) {
                        throw new Exception("Timeout waiting for SPI data... " + totalRead + " of " + target);
                    }

                    Thread.sleep(1);

                    read = is.read(buf);
                }

                this.receivedData = baos.toByteArray();

            } catch (Exception e) {
                Logger.getLogger(InputReadThread.class.getName()).log(Level.SEVERE, e.getMessage());
            }

        }
    }

}
