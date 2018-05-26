package de.maikmerten.spu32.emu;

import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.FocusEvent;
import java.awt.event.FocusListener;
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

	JFrame mainwindow = new JFrame("SPU32-emu");
	JPanel mainpanel = new JPanel();


	private SPU32Machine machine;

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

	public static void main(String[] args) throws Exception {
		Main m = new Main();
		m.constructAndStartEmulation();
	}
	

	private void setupMachine() throws Exception {
		machine = new SPU32Machine(getPreferenceValue(Preference.UART_DEV), getPreferenceValue(Preference.RAM_INITFILE), getPreferenceValue(Preference.SPIFLASH_INITFILE), getPreferenceValue(Preference.BOOTROM_INITFILE));
	}

	private void constructAndStartEmulation() throws Exception  {
		setupMachine();
		showUI();
		machine.startCPU();
	}

	private void showUI() {

		SwingUtilities.invokeLater(new Runnable() {

			@Override
			public void run() {
				mainwindow.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

				mainpanel.removeAll();
				mainpanel.setLayout(new GridLayout(1, 3));
				
				for(String key : machine.getGUIPanels().keySet()) {
					mainpanel.add(createTitledPanel(machine.getGUIPanels().get(key), key));
				}
				

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
				
				JMenu emuMenu = new JMenu("Emulation");
				menuBar.add(emuMenu);
				JMenuItem restartEmuMenuItem = new JMenuItem("Fresh emulation restart");
				restartEmuMenuItem.addActionListener(new ActionListener() {
					@Override
					public void actionPerformed(ActionEvent e) {
						try {
							machine.tearDown();
							constructAndStartEmulation();
						} catch(Exception exception) {
							throw new RuntimeException(exception);
						}
					}
				});
				emuMenu.add(restartEmuMenuItem);
				
				
				mainwindow.setJMenuBar(menuBar);

				mainwindow.add(mainpanel);
				mainwindow.pack();
				mainwindow.setVisible(true);
				mainwindow.setSize(550, 200);
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

		for (final Preference pref : Preference.values()) {
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
