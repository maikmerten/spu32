package de.maikmerten.spu32.emu;

import de.maikmerten.spu32.emu.bus.Bus;
import de.maikmerten.spu32.emu.cpu.CPUThread;
import de.maikmerten.spu32.emu.cpu.CPU;
import de.maikmerten.spu32.emu.busdevices.LEDs;
import de.maikmerten.spu32.emu.busdevices.RAM;
import de.maikmerten.spu32.emu.busdevices.UART;
import de.maikmerten.spu32.emu.cpu.CPUPanel;
import de.maikmerten.spu32.emu.serial.SerialConnection;
import java.awt.BorderLayout;
import java.awt.GridLayout;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.swing.JFrame;
import javax.swing.JPanel;
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

    private SerialConnection conn;

    public static void main(String[] args) {
        Main m = new Main();
        m.setupMachine();
        m.showUI();
        m.startEmulation();
    }

    private void setupMachine() {

        bus = new Bus();
        cpu = new CPU(bus, 0x0, 0x10);

        FileInputStream fis = null;
        try {
            fis = new FileInputStream(new File("/tmp/raminit.bin"));
        } catch (FileNotFoundException ex) {
            Logger.getLogger(Main.class.getName()).log(Level.SEVERE, null, ex);
        }
        ram = new RAM(12, fis);


        leds = new LEDs();


        uart = new UART("/dev/ttyUSB0", 115200);

        bus.setDefaultDevice(ram);
        bus.addDevice(0xFFFFF800, 0xFFFFFF00, uart);
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
                JFrame window = new JFrame("SPU32 emu");
                window.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

                mainpanel.setLayout(new GridLayout(1, 3));
                mainpanel.add(createTitledPanel(cpupanel, "CPU control"));
                mainpanel.add(createTitledPanel(leds.getGUIPanel(), "LEDs"));

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

}
