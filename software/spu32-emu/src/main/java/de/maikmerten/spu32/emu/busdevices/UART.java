package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.serial.SerialConnection;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class UART implements BusDevice {

    private SerialConnection conn;
    private InputStream is;
    private OutputStream os;
    byte buf = 0;

    public UART(String device, int rate) {

        try {
            conn = new SerialConnection(device, rate);
            is = conn.getInputStream();
            os = conn.getOutputStream();
        } catch (Exception ex) {
            Logger.getLogger(UART.class.getName()).log(Level.SEVERE, "could not open serial connection!", ex);
        }
    }
	
	public void tearDown() throws Exception {
		if(this.conn != null) {
			this.conn.getInputStream().close();
			this.conn.getOutputStream().close();
		}
	}

    @Override
    public byte read(int address) {
        address &= 0b11;

        byte result = 0;

        switch (address) {
            case 0:
                // read

                if (is != null) {
                    try {
                        if (is.available() > 0) {
                            byte[] tmp = new byte[1];
                            is.read(tmp);
                            buf = tmp[0];
                        }
                    } catch (IOException ex) {
                        Logger.getLogger(UART.class.getName()).log(Level.SEVERE, "IOException when calling available() on InputStream", ex);
                    }
                }

                result = buf;
                break;

            case 1:
                // signal read ready status
                int available = 0;

                if (is != null) {
                    try {
                        available = is.available();
                    } catch (IOException ex) {
                        Logger.getLogger(UART.class.getName()).log(Level.SEVERE, "IOException when calling available() on InputStream", ex);
                    }
                }
                result = (byte) (available > 0 ? 1 : 0);
                break;

            case 2:
                // signal write ready status
                result = (os != null) ? (byte) 1 : (byte) 0;
                break;
        }

        return result;
    }

    @Override
    public void write(int address, byte value) {
        address &= 0b11;

        if (address == 0) {
            byte[] tmp = new byte[1];
            tmp[0] = value;

            if (os != null) {
                try {
                    os.write(tmp);
                } catch (IOException ex) {
                    Logger.getLogger(UART.class.getName()).log(Level.SEVERE, "IOException when writing to OutputStream", ex);
                }
            }
        }
    }

}
