package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;

/**
 *
 * @author maik
 */
public class Timer implements BusDevice {
	
	long millis;

	@Override
	public byte read(int address) {
		int reg = address & 0x3;
		byte result = 0;
		
		switch(reg) {
			case 0: {
				millis = System.currentTimeMillis();
				result = (byte) (millis & 0xFF);
				break;
			}
			
			case 1: {
				result = (byte) ((millis >> 8) & 0xFF);
				break;
			}
			
			case 2: {
				result = (byte) ((millis >> 16) & 0xFF);
				break;
			}
			
			case 3: {
				result = (byte) ((millis >> 24) & 0xFF);
				break;
			}
		}
		
		return result;
	}

	@Override
	public void write(int address, byte value) {
		
	}
	
}
