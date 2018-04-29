package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.spiflash.SPIFlash;
import java.io.InputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class SPIPortWithFlash implements BusDevice {

	private final SPIFlash spidevice;
	private byte rxdata = 0;
	private boolean selected = false;
	private boolean busy = false;

	public SPIPortWithFlash(InputStream initStream) {
		spidevice = new SPIFlash(initStream);
	}

	@Override
	public byte read(int address) {
		address &= 0x03;
		byte result;

		switch (address) {
			case 0: {
				result = rxdata;
				break;
			}

			case 1: {
				result = selected ? (byte) 0x01 : (byte) 0x00;
				break;
			}

			default: {
				// pretend to be busy after a data read/write
				result = busy ? (byte) 0x00 : (byte) 0x01;
				busy = false;
			}
		}

		return result;
	}

	@Override
	public void write(int address, byte value) {
		address &= 0x03;

		switch (address) {
			case 0: {
				if (busy) {
					Logger.getLogger(SPIPortWithFlash.class.getName()).log(Level.SEVERE, "Writing data to SPI port that is still busy! Read ready flag before writing!");
				}
				rxdata = spidevice.readWriteByte(value);
				busy = true;
				break;
			}

			case 1: {
				selected = (value & 0x01) == 1;
				if (selected) {
					spidevice.select();
				} else {
					spidevice.deselect();
				}
				break;
			}

			default: {
				// do nothing on other addresses
			}
		}
	}

}
