package de.maikmerten.spu32.serialbootloader;

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

    public void callAddress(int address) throws Exception {
        byte a0 = (byte) ((address >> 24) & 0xFF);
        byte a1 = (byte) ((address >> 16) & 0xFF);
        byte a2 = (byte) ((address >> 8) & 0xFF);
        byte a3 = (byte) (address & 0xFF);

        byte[] cmd = {'C', a0, a1, a2, a3};
        bytesOut(cmd);
    }

}
