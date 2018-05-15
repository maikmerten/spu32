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
		CHIPERASE2(0xC7),
		WRITEENABLE(0x06),
		WRITEDISABLE(0x04),
		READSTATUS1(0x05),
		READSTATUS2(0x35),
		PAGEPROGRAM(0x02);

		private final byte cmdValue;

		private Command(int cmdValue) {
			this.cmdValue = (byte) (cmdValue & 0xFF);
		}
	}

	private enum State {
		IDLE,
		READADDR1,
		READADDR2,
		READADDR3,
		READDUMMY,
		READ,
		STATUSBYTE1,
		STATUSBYTE2,
		SURPLUSBYTE,
		PROGRAMADDR1,
		PROGRAMADDR2,
		PROGRAMADDR3,
		PROGRAMBUFFER,
	}

	// emulate a AT25SF041 SPI serial flash device, 4 MBit capacity
	private byte data[] = new byte[512 * 1024];
	private byte progbuffer[] = new byte[256];
	private byte cmd = 0;
	private State state = State.IDLE;
	private int addr = 0;
	private int progstartaddr = 0;
	private int progbyteindex = 0;
	private boolean selected = false;
	private boolean chiperase = false;
	private boolean writeenabled = false;
	private boolean progpage = false;
	private long busyEndTime = 0;

	private final Logger logger = Logger.getLogger(SPIFlash.class.getName());

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
		
		if (progpage) {
			writePageBufferToDataArray(progstartaddr);
			progpage = false;
			writeenabled = false;
			busyEndTime = System.currentTimeMillis() + 2;
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
				cmd = b;
				if (b == Command.READ.cmdValue || b == Command.FASTREAD.cmdValue) {
					state = State.READADDR1;
				} else if (b == Command.CHIPERASE1.cmdValue || b == Command.CHIPERASE2.cmdValue) {
					if (writeenabled) {
                                            if (chiperase) {
                                                logger.log(Level.WARNING, "Data sent to SPI flash despite chip erase already pending!");
                                            }
                                            chiperase = true;
					} else {
						logger.log(Level.SEVERE, "Issued chip erase command to SPI flash although writes are disabled!");
					}
				} else if (b == Command.WRITEENABLE.cmdValue) {
					writeenabled = true;
					state = State.SURPLUSBYTE;
				} else if (b == Command.WRITEDISABLE.cmdValue) {
					writeenabled = false;
					state = State.SURPLUSBYTE;
				} else if (b == Command.READSTATUS1.cmdValue) {
					state = State.STATUSBYTE1;
				} else if (b == Command.READSTATUS2.cmdValue) {
					state = State.STATUSBYTE2;
				} else {
					logger.log(Level.SEVERE, "Unrecognized command sent to SPI flash!");
				}
				break;
			}

			case READADDR1: {
				addr = (b & 0xFF);
				state = State.READADDR2;
				break;
			}

			case READADDR2: {
				addr = (addr << 8) | (b & 0xFF);
				state = State.READADDR3;
				break;
			}

			case READADDR3: {
				addr = (addr << 8) | (b & 0xFF);
				if(cmd == Command.FASTREAD.cmdValue) {
					state = State.READDUMMY;
				} else {
					state = State.READ;
				}
				break;
			}
			
			case READDUMMY: {
				state = State.READ;
				break;
			}

			case READ: {
				result = data[getAddrAndIncrement()];
				break;
			}

			case STATUSBYTE1: {
				// TODO: implement status bits 7 downto 2
				if (isBusy()) {
					result |= 0x01;
				}

				if (writeenabled) {
					result |= 0x02;
				}
				break;
			}

			case STATUSBYTE2: {
				// TODO: implement this properly
				logger.log(Level.WARNING, "status byte 2 of SPI flash is currently hardcoded to zero...");
				break;
			}

			case PROGRAMADDR1: {
				addr = (byte) (b & 0xFF);
				state = State.PROGRAMADDR2;
				break;
			}

			case PROGRAMADDR2: {
				addr = (addr << 8) | (b & 0xFF);
				state = State.PROGRAMADDR3;
				break;
			}

			case PROGRAMADDR3: {
				addr = (addr << 8) | (b & 0xFF);
				progstartaddr = addr;
				copyPageToProgBuffer(progstartaddr);
				progpage = true;
				progbyteindex = addr & 0xFF;
				state = State.PROGRAMBUFFER;
				break;
			}

			case PROGRAMBUFFER: {
				pushByteToProgBuffer(b);
				break;
			}

			case SURPLUSBYTE: {
				logger.log(Level.WARNING, "SPI flash received surplus data after command!");
				break;
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

	private void copyPageToProgBuffer(int startaddr) {
		startaddr &= 0x7FF00;
		for (int i = 0; i < 256; ++i) {
			progbuffer[i] = data[startaddr + i];
		}
	}

	private void pushByteToProgBuffer(byte data) {
		byte origvalue = progbuffer[progbyteindex];
		if (origvalue != (byte) 0xFF) {
			logger.log(Level.SEVERE, "Programming memory locatin in SPI flash that was not properly cleared beforehand!");
		}
		data &= origvalue;
		progbuffer[progbyteindex] = data;
		progbyteindex = (progbyteindex + 1) & 0xFF;
	}
	
	private void writePageBufferToDataArray(int pageaddr) {
		pageaddr &= 0x7FF00;
		for(int i = 0; i < 256; ++i) {
			data[pageaddr + i] = progbuffer[i];
		}
	}

	private boolean isBusy() {
		return System.currentTimeMillis() < busyEndTime;
	}

}
