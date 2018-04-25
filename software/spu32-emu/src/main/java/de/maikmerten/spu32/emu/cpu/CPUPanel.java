package de.maikmerten.spu32.emu.cpu;

import java.awt.GridLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import javax.swing.JButton;
import javax.swing.JPanel;

/**
 *
 * @author maik
 */
public class CPUPanel extends JPanel {

    private final CPUThread cputhread;
    private final JButton pausebutton, unpausebutton, resetbutton;

    public CPUPanel(final CPUThread cputhread) {
        this.cputhread = cputhread;

        this.setLayout(new GridLayout(3, 1));
        this.pausebutton = new JButton("Pause");
        this.pausebutton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                cputhread.pause();
            }
        });

        this.unpausebutton = new JButton("Unpause");
        this.unpausebutton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                cputhread.unpause();
            }
        });

        this.resetbutton = new JButton("Reset");
        this.resetbutton.addActionListener(new ActionListener() {
            @Override
            public void actionPerformed(ActionEvent e) {
                cputhread.reset();
            }
        });

        this.add(this.pausebutton);
        this.add(this.unpausebutton);
        this.add(this.resetbutton);
    }

}
