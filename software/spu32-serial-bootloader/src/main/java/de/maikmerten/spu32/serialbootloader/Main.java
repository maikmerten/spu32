package de.maikmerten.spu32.serialbootloader;

import java.io.File;

/**
 *
 * @author maik
 */
public class Main {

    public static void main(String[] args) throws Exception {
        if(args.length != 2) {
            System.out.println("Parameters: <serial device> <file to upload and execute>");
            System.exit(1);
        }
        
        String uartDevice = args[0];
        String programFile = args[1];
        
        System.out.println("UART device: " + uartDevice);
        System.out.println("file to program: " + programFile);
        
        SerialConnection conn = new SerialConnection(uartDevice, 115200);
        BootloaderProtocol bp = new BootloaderProtocol(conn);
        SPIFlasher flasher = new SPIFlasher(bp);

        File f = new File(programFile);
        flasher.programFile(f);

        
        
        
        //System.out.println("Uploading " + uploadData.length + " bytes...");
        //bp.uploadWithUART(0, uploadData);
        //bp.callAddress(0);

    }

}
