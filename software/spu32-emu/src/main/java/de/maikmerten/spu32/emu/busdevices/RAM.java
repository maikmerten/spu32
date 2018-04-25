package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import java.io.IOException;
import java.io.InputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class RAM implements BusDevice {

    private final byte[] ram;

    public RAM() {
        this(19);
    }

    public RAM(int addrbits) {
        this(addrbits, null);
    }

    public RAM(int addrbits, InputStream initData) {
        ram = new byte[(int) Math.pow(2, addrbits)];
        try {
            if (initData != null) {
                int adr = 0;
                byte[] buf = new byte[1];
                int read = initData.read(buf);
                while (read != -1) {
                    ram[adr] = buf[0];
                    read = initData.read(buf);
                    adr++;
                }
                Logger.getLogger(ROM.class.getName()).log(Level.INFO, "RAM init with " + adr + " bytes");
            }
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        }
    }

    @Override
    public byte read(int address) {
        int adr = address & (ram.length - 1);
        return ram[adr];
    }

    @Override
    public void write(int address, byte value) {
        int adr = address & (ram.length - 1);
        ram[adr] = value;
    }

}
