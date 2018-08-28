package de.maikmerten.spu32.emu;

import de.maikmerten.spu32.emu.bus.Bus;
import de.maikmerten.spu32.emu.busdevices.LEDs;
import de.maikmerten.spu32.emu.busdevices.RAM;
import de.maikmerten.spu32.emu.busdevices.ROM;
import de.maikmerten.spu32.emu.busdevices.SPIPortWithFlash;
import de.maikmerten.spu32.emu.busdevices.Timer;
import de.maikmerten.spu32.emu.busdevices.UART;
import de.maikmerten.spu32.emu.cpu.CPU;
import de.maikmerten.spu32.emu.cpu.CPUPanel;
import de.maikmerten.spu32.emu.cpu.CPUThread;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JPanel;

/**
 *
 * @author maik
 */
public class SPU32Machine {

	private String uartDev;
	private String raminitfile;
	private String spiflashinitfile;
	private String bootrominitfile;
	
	private CPUThread cputhread;
	private Bus bus;
	private CPU cpu;
	private RAM ram;
	private LEDs leds;
	private UART uart;
	private Timer timer;
	private SPIPortWithFlash spiport;
	private ROM bootrom;
	private CPUPanel cpupanel;

	public SPU32Machine(String uartDev, String raminitfile, String spiflashinitfile, String bootrominitfile) throws Exception {
		this.uartDev = uartDev;
		this.raminitfile = raminitfile;
		this.spiflashinitfile = spiflashinitfile;
		this.bootrominitfile = bootrominitfile;
		constructMachine();
	}
	
	public void constructMachine() throws Exception {
		tearDown();

		bus = new Bus();
		cpu = new CPU(bus, 0xFFFFF000, 0x10);

		FileInputStream raminit = null;
		try {
			raminit = new FileInputStream(new File(raminitfile));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}

		FileInputStream spiflashinit = null;
		try {
			spiflashinit = new FileInputStream(new File(spiflashinitfile));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}

		FileInputStream bootrominit = null;
		try {
			bootrominit = new FileInputStream(new File(bootrominitfile));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}

		ram = new RAM(19, raminit);
		leds = new LEDs();
		uart = new UART(uartDev, 115200);
		timer = new Timer();
		spiport = new SPIPortWithFlash(spiflashinit);
		bootrom = new ROM(9, bootrominit);

		bus.setDefaultDevice(ram);
		bus.addDevice(0xFFFFF000, 0xFFFFF7FF, bootrom);
		bus.addDevice(0xFFFFF800, 0xFFFFF8FF, uart);
		bus.addDevice(0xFFFFF900, 0xFFFFF9FF, spiport);
		bus.addDevice(0xFFFFFD00, 0xFFFFFDFF, timer);
		bus.addDevice(0xFFFFFF00, 0xFFFFFFFF, leds);

		cputhread = new CPUThread(cpu);
		cputhread.start();
		cpupanel = new CPUPanel(cputhread);

	}

	public void startCPU() {
		cputhread.unpause();
	}

	public void tearDown() throws Exception {
		if(this.uart != null) {
			this.uart.tearDown();
		}
		
		if(this.cputhread != null) {
			this.cputhread.terminate();
		}
	}

	public Map<String, JPanel> getGUIPanels() {
		Map<String, JPanel> result = new LinkedHashMap<>();
		result.put("CPU", cpupanel);
		result.put("LEDs", leds.getGUIPanel());

		return result;
	}


}
