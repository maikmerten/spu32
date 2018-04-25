package de.maikmerten.spu32.emu.interfaces;

/**
 *
 * @author maik
 */
public interface BusDevice {

    public byte read(int address);

    public void write(int address, byte value);

}
