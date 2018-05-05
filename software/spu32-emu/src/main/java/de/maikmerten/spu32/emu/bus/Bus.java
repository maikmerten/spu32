package de.maikmerten.spu32.emu.bus;

import de.maikmerten.spu32.emu.busdevices.DummyDevice;
import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.interfaces.InterruptSource;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 *
 * @author maik
 */
public class Bus implements InterruptSource {

    private final List<InterruptSource> interruptSources = new ArrayList<>();
	private final List<DeviceWrapper> devices = new ArrayList<>();

    private BusDevice defaultDevice = new DummyDevice(false);
	
	private class DeviceWrapper {
		private int startAddress, endAddress;
		private BusDevice dev;
		private DeviceWrapper(BusDevice dev, int start, int end) {
			this.dev = dev;
			this.startAddress = start;
			this.endAddress = end;
		}
	}

    public void addDevice(int startAddr, int endAddr, BusDevice device) {

		devices.add(new DeviceWrapper(device, startAddr, endAddr));

        if (device instanceof InterruptSource) {
            interruptSources.add((InterruptSource) device);
        }

    }

    public void setDefaultDevice(BusDevice device) {
        this.defaultDevice = device;
    }

    public byte readByte(int address) {
        BusDevice device = getDeviceFromAddress(address);
        return device.read(address);
    }

    public void writeByte(int address, byte b) {
        getDeviceFromAddress(address).write(address, b);
    }

    private BusDevice getDeviceFromAddress(int address) {
       
        for(DeviceWrapper wrapper : devices) {
			if(address >= wrapper.startAddress && address <= wrapper.endAddress) {
				return wrapper.dev;
			}
		}

        return defaultDevice;
    }

    @Override
    public boolean interruptRaised() {
        boolean result = false;
        for (InterruptSource isrc : interruptSources) {
            result |= isrc.interruptRaised();
        }
        return result;
    }

}
