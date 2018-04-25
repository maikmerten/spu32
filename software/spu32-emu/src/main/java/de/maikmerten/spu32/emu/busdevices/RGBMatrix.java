package de.maikmerten.spu32.emu.busdevices;

import de.maikmerten.spu32.emu.interfaces.BusDevice;
import de.maikmerten.spu32.emu.interfaces.GUIProvider;
import java.awt.Color;
import java.awt.Graphics;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;

/**
 *
 * @author maik
 */
public class RGBMatrix implements BusDevice, GUIProvider {

    private final RGBMatrixPanel panel = new RGBMatrixPanel();
    private final byte[] rgbdata = new byte[512];

    @Override
    public byte read(int address) {
        return rgbdata[address & 0x1FF];
    }

    @Override
    public void write(int address, byte value) {
        rgbdata[address & 0x1FF] = value;
        panel.repaint();
    }

    @Override
    public JPanel getGUIPanel() {
        return panel;
    }

    private class RGBMatrixPanel extends JPanel {

        @Override
        public void paintComponent(Graphics g) {
            if (!SwingUtilities.isEventDispatchThread()) {
                throw new RuntimeException("paintComponent executed outside of event dispatch thread!");
            }
            super.paintComponent(g);

            int offset = 0;

            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int grn = rgbdata[offset++] & 0xFF;
                    int red = rgbdata[offset++] & 0xFF;
                    int blu = rgbdata[offset++] & 0xFF;

                    grn = Math.max(0, Math.min(255, grn * 16));
                    red = Math.max(0, Math.min(255, red * 16));
                    blu = Math.max(0, Math.min(255, blu * 16));

                    int rgb = (red << 16 | grn << 8 | blu);
                    g.setColor(new Color(rgb));
                    g.fillRect((x * 16) + 8, (y * 16) + 8, 16, 16);

                }
            }

        }

    }

}
