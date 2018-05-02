package de.maikmerten.spu32.serialbootloader;

/**
 *
 * @author maik
 */
public class Main {

    public static void main(String[] args) throws Exception {
        SerialConnection conn = new SerialConnection("/dev/ttyUSB1", 115200);
        BootloaderProtocol bp = new BootloaderProtocol(conn);
        
        bp.callAddress(0);

    }

}
