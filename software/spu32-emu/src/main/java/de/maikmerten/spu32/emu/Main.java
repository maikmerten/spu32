package de.maikmerten.spu32.emu;

import de.maikmerten.spu32.emu.bus.Bus;
import de.maikmerten.spu32.emu.cpu.CPUThread;
import de.maikmerten.spu32.emu.cpu.CPU;
import de.maikmerten.spu32.emu.busdevices.LEDs;
import de.maikmerten.spu32.emu.busdevices.RAM;
import de.maikmerten.spu32.emu.busdevices.ROM;
import de.maikmerten.spu32.emu.busdevices.SPIPortWithFlash;
import de.maikmerten.spu32.emu.busdevices.Timer;
import de.maikmerten.spu32.emu.busdevices.UART;
import de.maikmerten.spu32.emu.cpu.CPUPanel;
import de.maikmerten.spu32.emu.serial.SerialConnection;
import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.prefs.Preferences;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JMenu;
import javax.swing.JMenuBar;
import javax.swing.JMenuItem;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.SwingUtilities;
import javax.swing.border.TitledBorder;

/**
 *
 * @author maik
 */
public class Main {

	JPanel mainpanel = new JPanel();

	private CPUThread cputhread;
	private CPUPanel cpupanel;

	private RAM ram;
	private Bus bus;
	private LEDs leds;
	private CPU cpu;
	private UART uart;
	private Timer timer;
	private SPIPortWithFlash spiport;
        private ROM bootrom;

	private SerialConnection conn;

	private enum Preference {
		UART_DEV("uart_dev", "/dev/ttyUSB0", "Serial device to be used for UART"),
		RAM_INITFILE("ram_initfile", "/tmp/raminit.bin", "File with initial RAM contents"),
                BOOTROM_INITFILE("bootrom_initfile", "/tmp/bootrominit.bin", "File with boot-ROM contents"),
		SPIFLASH_INITFILE("spiflash_initfile", "/tmp/spiflashinit.bin", "File with initial SPI flash contents");
		
		private final String key;
		private final String defaultval;
		private final String description;
		private Preference(String key, String defaultval, String description) {
			this.key = key;
			this.defaultval = defaultval;
			this.description = description;
		}
	}

	public static void main(String[] args) {
		Main m = new Main();
		m.setupMachine();
		m.showUI();
		m.startEmulation();
	}

	private void setupMachine() {

		bus = new Bus();
		cpu = new CPU(bus, 0xFFFFFB00, 0x10);

		FileInputStream raminit = null;
		try {
			raminit = new FileInputStream(new File(getPreferenceValue(Preference.RAM_INITFILE)));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}

		FileInputStream spiflashinit = null;
		try {
			spiflashinit = new FileInputStream(new File(getPreferenceValue(Preference.SPIFLASH_INITFILE)));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}
                
                FileInputStream bootrominit = null;
                try {
			bootrominit = new FileInputStream(new File(getPreferenceValue(Preference.BOOTROM_INITFILE)));
		} catch (FileNotFoundException ex) {
			Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
		}

		ram = new RAM(12, raminit);
		leds = new LEDs();
		uart = new UART(getPreferenceValue(Preference.UART_DEV), 115200);
		timer = new Timer();
		spiport = new SPIPortWithFlash(spiflashinit);
                bootrom = new ROM(8, bootrominit);

		bus.setDefaultDevice(ram);
		bus.addDevice(0xFFFFF800, 0xFFFFFF00, uart);
		bus.addDevice(0xFFFFF900, 0xFFFFFF00, spiport);
                bus.addDevice(0xFFFFFB00, 0xFFFFFF00, bootrom);
		bus.addDevice(0xFFFFFD00, 0xFFFFFF00, timer);
		bus.addDevice(0xFFFFFF00, 0xFFFFFF00, leds);

		cputhread = new CPUThread(cpu);
		cputhread.start();
		cpupanel = new CPUPanel(cputhread);

	}

	private void startEmulation() {
		cputhread.unpause();
	}

	private void showUI() {

		SwingUtilities.invokeLater(new Runnable() {

			@Override
			public void run() {
				JFrame window = new JFrame("SPU32-emu");
				window.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

				mainpanel.setLayout(new GridLayout(1, 3));
				mainpanel.add(createTitledPanel(cpupanel, "CPU control"));
				mainpanel.add(createTitledPanel(leds.getGUIPanel(), "LEDs"));

				JMenuBar menuBar = new JMenuBar();
				JMenu prefMenu = new JMenu("Preferences");
				menuBar.add(prefMenu);
				JMenuItem prefMenuItem = new JMenuItem("Edit preferences");
				prefMenuItem.addActionListener(new ActionListener() {
					@Override
					public void actionPerformed(ActionEvent e) {
						showPreferencesUI();
					}
				});
				
				prefMenu.add(prefMenuItem);
				window.setJMenuBar(menuBar);

				window.add(mainpanel);
				window.pack();
				window.setVisible(true);
				window.setSize(550, 200);
			}

			private JPanel createTitledPanel(JPanel panel, String title) {
				JPanel p = new JPanel();
				p.setBorder(new TitledBorder(title));
				p.setLayout(new BorderLayout());
				p.add(panel, BorderLayout.CENTER);

				return p;
			}

		});

	}

	private void showPreferencesUI() {
		if (!SwingUtilities.isEventDispatchThread()) {
			throw new RuntimeException("constructing UI outside of event dispatch thread!");
		}

		JFrame prefwindow = new JFrame("SPU32-emu preferences");
		prefwindow.setDefaultCloseOperation(JFrame.DISPOSE_ON_CLOSE);
		
		JPanel prefpanel = new JPanel(new GridLayout(0, 2));
		
		for(final Preference pref : Preference.values()) {
			final JLabel label = new JLabel(pref.description);
			final JTextField field = new JTextField(getPreferenceValue(pref));
			
			field.addFocusListener(new FocusListener() {
				@Override
				public void focusGained(FocusEvent e) {
				}

				@Override
				public void focusLost(FocusEvent e) {
					// save preference when input field is deselected
					setPreferenceValue(pref, field.getText());
				}
			});
			
			prefpanel.add(label);
			prefpanel.add(field);
		}
		
		prefwindow.add(prefpanel);

		prefwindow.pack();
		prefwindow.setVisible(true);
		prefwindow.setSize(550, 35 * Preference.values().length);

	}
	
	private String getPreferenceValue(Preference pref) {
		Preferences prefs = Preferences.userNodeForPackage(Main.class);
		return prefs.get(pref.key, pref.defaultval);
	}
	
	private void setPreferenceValue(Preference pref, String value) {
		Logger.getLogger(Main.class.getName()).log(Level.INFO, "setting preference " + pref.key + " to value " + value);
		Preferences prefs = Preferences.userNodeForPackage(Main.class);
		prefs.put(pref.key, value);
	}

}
