#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>
#include <ctype.h>
#include <signal.h>

struct termios termsave;
int fd_tty;

const char CMD_CHIP_ERASE = (char) 0x60;
const char CMD_FASTREAD = (char) 0x0B;
const char CMD_PAGE_PROGRAM = (char) 0x02;
const char CMD_READ_STATUS = (char) 0x05;
const char CMD_WRITE_ENABLE = (char) 0x06;

const int CHUNKSIZE = 32;


int set_interface_attribs(int fd, int speed) {
    struct termios tty;
    memset(&tty, 0, sizeof tty);
    if (tcgetattr(fd, &tty) != 0)
    {
        perror("error from tcgetattr");
        return -1;
    }

    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8; // 8-bit chars
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON | IXOFF | IXANY);
    tty.c_lflag = 0;
    tty.c_oflag = 0;

    tty.c_cflag |= (CLOCAL | CREAD);   // ignore modem controls,
    tty.c_cflag &= ~(PARENB | PARODD | CSTOPB);

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        perror("error from tcsetattr");
        return -1;
    }
    return 0;
}

void toggleRTS() {
    int RTS_flag = TIOCM_RTS;
    ioctl(fd_tty, TIOCMBIS,&RTS_flag); // set RTS signal
    usleep(10 * 1000); // sleep a while
    ioctl(fd_tty, TIOCMBIC,&RTS_flag);// clear RTS signal
    usleep(5 * 1000); // give bootloader a chance to start
}


void assemble32(char *buf, int dat32) {
    buf[0] = (char) ((dat32 >> 24) & 0xFF);
    buf[1] = (char) ((dat32 >> 16) & 0xFF);
    buf[2] = (char) ((dat32 >> 8) & 0xFF);
    buf[3] = (char) (dat32 & 0xFF);
}

void uploadFile(char *filename, int address) {
    int fd = open (filename, O_RDONLY);
    if(fd == -1) {
        perror("could not open input file");
        return;
    }

    char filebuf[1024*1024];
    int file_read = read(fd, filebuf, sizeof filebuf);
    printf("read %d bytes for upload\n\r", file_read);
    close(fd);

    char cmd_upload[9];
    cmd_upload[0] = 'U';
    assemble32(&cmd_upload[1], 0); // upload address
    assemble32(&cmd_upload[5], file_read); // upload size

    toggleRTS(fd_tty);

    write(fd_tty, cmd_upload, sizeof cmd_upload);
    write(fd_tty, filebuf, file_read);
}

void callAddress(int address) {
    char cmd_call[5];
    cmd_call[0] = 'C';
    assemble32(&cmd_call[1], 0);
    write(fd_tty, cmd_call, sizeof cmd_call);
}

void console() {
    struct termios termcfg;
    tcgetattr(0, &termcfg);
    termcfg.c_lflag &= ~(ECHO | ICANON); // turn off echo, buffer
    tcsetattr(0, 0, &termcfg);

    // set stdin to non-blocking reads
    fcntl(0, F_SETFL, fcntl(0, F_GETFL) | O_NONBLOCK);

    while(1) {
        int n;
        char c;
        char active = 0;

        n = read(0, &c, 1);
        if(n > 0) {
            active = 1;
            write(fd_tty, &c, 1);
        }

        n = read(fd_tty, &c, 1);
        if(n > 0) {
            active = 1;
            write(1, &c, 1);
        }

        if(!active) {
            usleep(3 * 1000);
        }
    }

}

void drainfd() {
    char c;
    int n;
    do {
        n = read(fd_tty, &c, 1);
    } while(n > 0);
}

int writeToSPI(char *data, char *response, int length) {
    drainfd();


    char op[1];
    char len[4];
    op[0] = 'S';
    assemble32(len, length);

    write(fd_tty, op, sizeof op);
    write(fd_tty, len, sizeof len);
    write(fd_tty, data, length);


    int received = 0;
    do {
        char recbuf[64];
        int n = read(fd_tty, recbuf, sizeof recbuf);
        if(n < 0) {
            //perror("error on reading SPI response");
            //return -1;
            usleep(1 * 1000);
        }
        if(n > 0) {
            for(int i = 0; i < n; ++i) {
                int ridx = received + i;
                if(ridx < length) {
                    response[ridx] = recbuf[i];
                }
            }
            received += n;
        } 
    } while(received < length);

    return 0;
}

void addr24(int addr, char *buf) {
    buf[0] = (char)((addr >> 16) & 0xFF);
    buf[1] = (char)((addr >> 8) & 0xFF);
    buf[2] = (char)(addr & 0xFF);
}

int isBusy() {
    // op and one dummy byte
    char op[2];
    op[0] = CMD_READ_STATUS;
    op[1] = CMD_READ_STATUS;
    writeToSPI(op, op, sizeof op);
    int busy = (op[1] & 0x01);
    return busy;
}

void enableWrite() {
    char cmd[1];
    cmd[0] = CMD_WRITE_ENABLE;
    writeToSPI(cmd, cmd, sizeof cmd);
}

void readChunk(int addr, char *buf, int len) {
    while(isBusy()) {
        usleep(1 * 1000);
    }
    char spidata[1 + 3 + 1 + len];
    spidata[0] = CMD_FASTREAD; // cmd
    addr24(addr, &spidata[1]);
    spidata[4] = CMD_FASTREAD; // dummy byte

    writeToSPI(spidata, spidata, sizeof spidata);
    for(int i = 0; i < len; ++i) {
        buf[i] = spidata[5 + i];
    }
}

void programChunk(int addr, char *data, int chunksize) {
    char spidata[1 + 3 + chunksize];

    spidata[0] = CMD_PAGE_PROGRAM;
    addr24(addr, &spidata[1]);

    for(int i = 0; i < chunksize; ++i) {
        spidata[4 + i] = data[i];
    }

    enableWrite();
    writeToSPI(spidata, spidata, sizeof spidata);
    while(isBusy()) {
        usleep(1 * 1000);
    }
}

void programFile(char *filename) {
    int fd = open (filename, O_RDONLY);
    if(fd == -1) {
        perror("could not open input file");
        return;
    }

    int chunk = 0;
    int addr = 0;
    int n;
    do {
        char buf[CHUNKSIZE];
        char buf2[CHUNKSIZE];

        n = read(fd, buf, CHUNKSIZE);

        programChunk(addr, buf, n);
        readChunk(addr, buf2, n);

        for(int i = 0; i < n; ++i) {
            char expected = buf[i];
            char readback = buf2[i];
            if(readback != expected) {
                printf("write/read mismatch at address %d %04x. Expected %02x, but read back %02x\n", addr + i, addr + i, expected, readback);
            }
        }

        addr += n;
    } while(n > 0);

    close(fd);
}

void eraseChip() {
    char cmd[1];
    cmd[0] = CMD_CHIP_ERASE;
    writeToSPI(cmd, cmd, sizeof cmd);
}


void cleanup() {
    close(fd_tty);
    tcsetattr(0, 0, &termsave);
    printf("bye.\n\r");
    exit(0);
}

void sigint() {
    exit(0);
}


int main(int argc, char *argv[])
{
    atexit(cleanup);
    signal(SIGINT, sigint);
    // save terminal state
    tcgetattr(0, &termsave);

    char *filename = NULL;
    char *portname = NULL;
    char enterconsole = 0, program = 0;

    int c;
    opterr = 0;

    while ((c = getopt (argc, argv, "cd:f:p")) != -1) {
        switch (c) {
            case 'c':
                enterconsole = 1;
                break;
            case 'd':
                portname = optarg;
                break;
            case 'f':
                filename = optarg;
                break;
            case 'p':
                program = 1;
                break;
      
            case '?':
                if (optopt == 'd' || optopt == 'f') {
                    fprintf (stderr, "Option -%c requires an argument.\n", optopt);
                } else if (isprint (optopt)) {
                    fprintf (stderr, "Unknown option `-%c'.\n", optopt);
                } else {
                    fprintf (stderr, "Unknown option character `\\x%x'.\n", optopt);
                }
                return 1;
            default:
                abort ();
        }
    }
    
    int fd_file = open (filename, O_RDONLY);
    if(fd_file == -1) {
        perror("could not open input file");
        return 1;
    }


    fd_tty = open(portname, O_RDWR | O_NOCTTY | O_SYNC | O_NONBLOCK);
    if (fd_tty < 0)
    {
        perror("error opening serial port");
        return 1;
    }
    set_interface_attribs(fd_tty, B115200);


    toggleRTS();

    if(program) {
        enableWrite();
        eraseChip();
        printf("erasing chip...\n");
        while(isBusy()) {}
        printf("... aaaand it's gone!\n");
        printf("\n\r");
        programFile(filename);
    } else {
        uploadFile(filename, 0);
        callAddress(0);
    }

    if(enterconsole) {
        console();
    }


    return 0;
}
