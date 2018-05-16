package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;

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
        flasher.enableWrite();
        flasher.eraseChip();
        while(flasher.isBusy()) {
            System.out.print(".");
        }
        System.out.println();
        
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        File f = new File(programFile);
        FileInputStream fis = new FileInputStream(f);
        byte[] buf = new byte[512];
        int read = fis.read(buf);
        while(read > 0) {
            baos.write(buf, 0, read);
            read = fis.read(buf);
        }
        fis.close();
        
        byte[] uploadData = baos.toByteArray();
        
        System.out.println("Uploading " + uploadData.length + " bytes...");
        bp.uploadWithUART(0, uploadData);
        bp.callAddress(0);

    }

}
