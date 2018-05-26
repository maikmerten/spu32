package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.interfaces.InterruptSource;

/**
 *
 * @author maik
 */
public class Timer implements BusDevice, InterruptSource {

	private long millis, millis_interrupt;
	boolean interrupt_armed = false;
	boolean interrupt_latched = false;

	@Override
	public byte read(int address) {
		int reg = address & 0x7;
		byte result = 0;

		switch (reg) {
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

			case 4: {
				interrupt_latched = false;
				result = (byte) (millis_interrupt & 0xFF);
				break;
			}

			case 5: {
				result = (byte) ((millis_interrupt >> 8) & 0xFF);
				break;
			}

			case 6: {
				result = (byte) ((millis_interrupt >> 16) & 0xFF);
				break;
			}

			case 7: {
				result = (byte) ((millis_interrupt >> 24) & 0xFF);
				break;
			}
		}

		return result;
	}

	@Override
	public void write(int address, byte value) {
		int reg = address & 0x7;

		switch (reg) {
			case 4: {
				millis_interrupt = (millis_interrupt & 0xFFFFFF00l) | (value & 0xFFl);
				break;
			}
			
			case 5: {
				millis_interrupt = (millis_interrupt & 0xFFFF00FFl) | ((value << 8) & 0xFF00l);
				break;
			}
			
			case 6: {
				millis_interrupt = (millis_interrupt & 0xFF00FFFFl) | ((value << 16) & 0xFF0000l);
				break;
			}
			
			case 7: {
				interrupt_armed = true;
				millis_interrupt = (millis_interrupt & 0x00FFFFFFl) | ((value << 24) & 0xFF000000l);
				break;
			}

		}

	}

	@Override
	public boolean interruptRaised() {
		long now32 = System.currentTimeMillis() & 0xFFFFFFFFl;
		if(now32 >= millis_interrupt && interrupt_armed) {
			interrupt_latched = true;
			interrupt_armed = false;
		}
		return interrupt_latched;
	}

}
