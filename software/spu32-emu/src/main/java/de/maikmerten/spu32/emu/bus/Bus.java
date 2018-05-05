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
	private final List<BusDevice> devices = new ArrayList<>();
    private final Map<BusDevice, Integer> startAddrs = new HashMap<>();
	private final Map<BusDevice, Integer> endAddrs = new HashMap<>();
    private final List<Integer> baseAddrs = new ArrayList<>();

    private BusDevice defaultDevice = new DummyDevice(false);

    public void addDevice(int startAddr, int endAddr, BusDevice device) {

		devices.add(device);
		startAddrs.put(device, startAddr);
		endAddrs.put(device, endAddr);

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
       
        for(BusDevice dev : devices) {
			int start = startAddrs.get(dev);
			int end = endAddrs.get(dev);
			if(address >= start && address <= end) {
				return dev;
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
