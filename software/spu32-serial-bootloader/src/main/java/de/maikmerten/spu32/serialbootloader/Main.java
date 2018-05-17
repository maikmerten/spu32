package de.maikmerten.spu32.serialbootloader;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.util.Random;

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
        
      
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        File f = new File(programFile);
        FileInputStream fis = new FileInputStream(f);
        byte[] buf = new byte[64];
        int read = fis.read(buf);
        while(read > 0) {
            baos.write(buf, 0, read);
            read = fis.read(buf);
        }
        fis.close();
        
        byte[] uploadData = baos.toByteArray();
        
        byte[] randomData = new byte[512 * 1024];
        Random r = new Random();
        r.nextBytes(randomData);
        
        ByteArrayInputStream bais = new ByteArrayInputStream(randomData);
        SPIFlasher flasher = new SPIFlasher(bp);
        flasher.enableWrite();
        System.out.print("erasing chip ");
        flasher.eraseChip();
        while(flasher.isBusy()) {
            System.out.print(".");
        }
        
  
        System.out.println();
        read = bais.read(buf);
        int chunk = 0;
        while(read > 0) {
            System.out.println("programming 64-byte chunk " + chunk + " ");
            flasher.enableWrite();
            flasher.programChunk(chunk, buf);
            while(flasher.isBusy()) {
                System.out.print(".");
            }
            byte[] chunkData = flasher.readChunk(chunk);
            for(int i = 0; i < buf.length; ++i) {
                if(chunkData[i] != buf[i]) {
                    throw new Exception("read chunk data does not match!");
                }
            }
            
            System.out.println();
            chunk++;
            read = bais.read(buf);
        }
        
        
        
        System.out.println("Uploading " + uploadData.length + " bytes...");
        bp.uploadWithUART(0, uploadData);
        bp.callAddress(0);

    }

}
