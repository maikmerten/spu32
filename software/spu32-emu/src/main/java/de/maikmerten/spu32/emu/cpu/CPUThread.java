package de.maikmerten.spu32.emu.cpu;

import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author maik
 */
public class CPUThread extends Thread {

    private final CPU cpu;
    private boolean run = false;
    private boolean terminate = false;
    private boolean doreset = false;

    public CPUThread(CPU cpu) {
        this.cpu = cpu;
    }

    @Override
    public synchronized void run() {
        int instructions = 0;

        while (true) {

            if (this.run) {

                if (doreset) {
                    cpu.reset();
                    doreset = false;
                }

                cpu.nextStep();
                instructions++;

                // throttle CPU speed by sleeping for a while after processing
                // a bunch of instructions
                if (instructions > 50000) {
                    try {
                        this.wait(10);
                    } catch (InterruptedException ex) {
                        Logger.getLogger(CPUThread.class.getName()).log(Level.SEVERE, "Exception when waiting in CPU thread", ex);
                    }
                    instructions = 0;
                }

            } else {
                try {
                    this.wait(100);
                } catch (InterruptedException ex) {
                    Logger.getLogger(CPUThread.class.getName()).log(Level.SEVERE, "Exception when waiting in CPU thread", ex);
                }
            }

            if (terminate) {
                return;
            }
        }

    }

    public void pause() {
        this.run = false;
    }

    public void unpause() {
        this.run = true;
    }

    public void reset() {
        this.doreset = true;
    }

    public void terminate() {
        this.terminate = true;
    }

}
