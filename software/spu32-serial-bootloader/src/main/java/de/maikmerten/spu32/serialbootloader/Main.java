package de.maikmerten.spu32.serialbootloader;

import java.io.File;
import java.io.InputStream;
import java.io.OutputStream;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.Options;

/**
 *
 * @author maik
 */
public class Main {

    public static void main(String[] args) throws Exception {

        Options opts = new Options();
        Option fileOption = new Option("f", "file", true, "file to be uploaded or programmed");
        fileOption.setRequired(true);
        Option deviceOption = new Option("d", "device", true, "serial device to be used");
        Option consoleOption = new Option("c", "console", false, "enter console mode after upload/programming");
        Option programOption = new Option("p", "program", false, "program file to SPI flash");

        opts.addOption(fileOption);
        opts.addOption(deviceOption);
        opts.addOption(consoleOption);
        opts.addOption(programOption);

        CommandLineParser cmdParser = new DefaultParser();
        CommandLine cmd = null;

        try {
            cmd = cmdParser.parse(opts, args);
        } catch (Exception e) {
            HelpFormatter formatter = new HelpFormatter();
            formatter.printHelp("(cmdname)", opts);
            System.exit(1);
        }

        String uartDevice = cmd.hasOption("device") ? cmd.getOptionValue("device") : "/dev/ttyUSB0";
        String programFile = cmd.getOptionValue("file");
        boolean program = cmd.hasOption("program");
        boolean console = cmd.hasOption("console");

        System.out.println("UART device: " + uartDevice);
        System.out.println("file: " + programFile);
        System.out.println("programming to flash: " + program);

        SerialConnection conn = new SerialConnection(uartDevice, 115200);
        BootloaderProtocol bp = new BootloaderProtocol(conn);
        SPIFlasher flasher = new SPIFlasher(bp);

        File f = new File(programFile);
        if (program) {
            flasher.programFile(f);
        } else {
            bp.uploadFile(0, f);
            bp.callAddress(0);
        }

        if (console) {
            // knock console into raw mode
            String[] execcmd = {"/bin/sh", "-c", "stty raw -echo </dev/tty"};
            Runtime.getRuntime().exec(execcmd).waitFor();
            
            System.out.println();

            byte[] buf = new byte[512];
            InputStream serialInput = conn.getInputStream();
            OutputStream serialOutput = conn.getOutputStream();
            while (true) {
                if (serialInput.available() > 0) {
                    int read = serialInput.read(buf);
                    System.out.write(buf, 0, read);
                }

                if (System.in.available() > 0) {
                    int read = System.in.read(buf);
                    if(buf[0] == 3) break; // ctrl-c
                    serialOutput.write(buf, 0, read);
                }

                Thread.sleep(1);
            }
            
            // reset console into normal mode
            String[] execcmd2 = {"reset"};
            Runtime.getRuntime().exec(execcmd2).waitFor();
            System.out.println();
        }

    }

}
