package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class DummyDevice implements BusDevice {

    private final boolean log;

    public DummyDevice(boolean log) {
        this.log = log;
    }

    @Override
    public byte read(int address) {
        if (log) {
            Logger.getLogger(DummyDevice.class.getName()).log(Level.SEVERE, "read on dummy device, address " + Integer.toHexString(address));
        }
        return 0;
    }

    @Override
    public void write(int address, byte value) {
        if (log) {
            Logger.getLogger(DummyDevice.class.getName()).log(Level.SEVERE, "write on dummy device, address " + Integer.toHexString(address));
        }
    }

}
