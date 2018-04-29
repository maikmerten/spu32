package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.interfaces.GUIProvider;
import java.awt.Color;
import java.awt.Graphics;
import java.awt.Toolkit;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

/**
 *
 * @author maik
 */
public class LEDs implements BusDevice, GUIProvider {

    private final LEDPanel panel = new LEDPanel();
    private byte value;

    @Override
    public byte read(int address) {
        return value;
    }

    @Override
    public void write(int address, byte value) {
        if ((address & 0xF) != 0) {
            return;
        }

        this.value = value;
        this.panel.setLEDs(value);
    }

    @Override
    public JPanel getGUIPanel() {
        return panel;
    }

    /**
     * A JPanel for the GUI
     */
    private class LEDPanel extends JPanel {

        private final Color[] ledcolors = new Color[8];
        private final Color on, off;

        public LEDPanel() {
            setLayout(null);
            on = new Color(0, 180, 0);
            off = new Color(0, 60, 0);
            setLEDs((byte) 0);
        }

        public final void setLEDs(byte value) {
            int mask = 0x80;
            for (int i = 7; i >= 0; --i) {
                ledcolors[i] = (value & mask) != 0 ? on : off;
                mask >>>= 1;
            }

            repaint();
        }

        @Override
        public void paintComponent(Graphics g) {
            if (!SwingUtilities.isEventDispatchThread()) {
                throw new RuntimeException("paintComponent executed outside of event dispatch thread!");
            }
            super.paintComponent(g);

            for (int i = 7; i >= 0; --i) {
                g.setColor(ledcolors[i]);
                g.fillRect(((7 - i) * 20) + 8, 18, 16, 16);
            }
			Toolkit.getDefaultToolkit().sync();
        }

    }

}
