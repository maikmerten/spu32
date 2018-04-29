package de.maikmerten.spu32.emu.spiflash;

import java.io.IOException;
import java.io.InputStream;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class SPIFlash {

	private enum Command {
		READ(0x03),
		FASTREAD(0x0B),
		CHIPERASE1(0x60),
		CHIPERASE2(0xC7);

		private final byte cmdValue;

		private Command(int cmdValue) {
			this.cmdValue = (byte) (cmdValue & 0xFF);
		}
	}

	private enum State {
		IDLE,
		FASTREADDUMMY,
		READADDR1,
		READADDR2,
		READADDR3,
		READ,
		CHIPERASE,
	}

	// emulate a AT25SF041 SPI serial flash device, 4 MBit capacity
	private byte data[] = new byte[512 * 1024];
	private State state = State.IDLE;
	private int addr = 0;
	private boolean selected = false;
	private boolean chiperase = false;
	private boolean writeenabled = false;
	private long busyEndTime = 0;
	
	private Logger logger = Logger.getLogger(SPIFlash.class.getName());

	public SPIFlash(InputStream initStream) {
		if (initStream != null) {
			byte[] buf = new byte[1];
			int dataaddr = 0;

			try {
				int read = initStream.read(buf);
				while (read > 0 && dataaddr < data.length) {
					data[dataaddr++] = buf[0];
					read = initStream.read(buf);
				}
			} catch (IOException ex) {
				throw new RuntimeException(ex);
			}

			logger.log(Level.INFO, "SPI flash init with " + dataaddr + " bytes");
		}
	}

	public void select() {
		if (this.selected) {
			logger.log(Level.WARNING, "Selecting already selected SPI flash device...");
		} else {
			this.selected = true;
			this.state = State.IDLE;
		}
	}

	public void deselect() {
		if (chiperase) {
			for (int i = 0; i < data.length; ++i) {
				data[i] = (byte) 0xFF;
			}
			busyEndTime = System.currentTimeMillis() + 800;
			chiperase = false;
		}

		this.selected = false;
	}

	public byte readWriteByte(byte b) {
		byte result = 0;
		if (!selected) {
			logger.log(Level.WARNING, "Interaction with SPI flash in unselected state!");
			return result;
		}

		switch (state) {
			case IDLE: {
				if (b == Command.READ.cmdValue) {
					state = State.READADDR1;
				} else if (b == Command.FASTREAD.cmdValue) {
					state = State.FASTREADDUMMY;
				} else if (b == Command.CHIPERASE1.cmdValue || b == Command.CHIPERASE2.cmdValue) {
					if(writeenabled) {
						state = State.CHIPERASE;
					} else {
						logger.log(Level.SEVERE, "Issued chip erase command to SPI flash although writes are disabled!");
					}
				} else {
					logger.log(Level.SEVERE, "Unrecognized command sent to SPI flash!");
				}
			}

			case FASTREADDUMMY: {
				state = State.READADDR1;
			}

			case READADDR1: {
				addr = (b & 0xFF);
				state = State.READADDR2;
			}

			case READADDR2: {
				addr = (addr << 8) | (b & 0xFF);
				state = State.READADDR3;
			}

			case READADDR3: {
				addr = (addr << 8) | (b & 0xFF);
				state = State.READ;
			}

			case READ: {
				result = data[getAddrAndIncrement()];
			}

			case CHIPERASE: {
				if (chiperase) {
					logger.log(Level.WARNING, "Data sent to SPI flash despite chip erase already pending!");
				}
				chiperase = true;
			}
		}

		return result;
	}

	private int getAddrAndIncrement() {
		int result = this.addr;
		// increment address, make sure the address wraps around within 19 bits
		this.addr = (this.addr + 1) & 0x7FFFF;
		return result;
	}
	
	private boolean isBusy() {
		return System.currentTimeMillis() >= busyEndTime;
	}

}
