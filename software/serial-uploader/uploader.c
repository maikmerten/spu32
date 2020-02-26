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
int testrun = 0;
int exitcode = 0;

const char CMD_CHIP_ERASE = (char) 0x60;
const char CMD_FASTREAD = (char) 0x0B;
const char CMD_PAGE_PROGRAM = (char) 0x02;
const char CMD_READ_STATUS = (char) 0x05;
const char CMD_WRITE_ENABLE = (char) 0x06;

const int CHUNKSIZE = 64;


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

void toggleReset() {
    int flags = TIOCM_RTS | TIOCM_DTR | TIOCM_CTS;
    ioctl(fd_tty, TIOCMBIS, &flags); // set flags to signal reset
    usleep(10 * 1000); // sleep a while
    ioctl(fd_tty, TIOCMBIC, &flags);// clear flags
    usleep(10 * 1000); // give bootloader a chance to start
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

    char cmd_upload[9];
    cmd_upload[0] = 'U';

    char filebuf[256];
    int n = read(fd, filebuf, sizeof filebuf);
    int ret;
    while(n > 0) {
        assemble32(&cmd_upload[1], address); // upload address
        assemble32(&cmd_upload[5], n); // upload size

	    ret = write(fd_tty, cmd_upload, sizeof cmd_upload);
        if(ret == -1) {
            perror("uploadFile: error writing to fd_tty (1)");
            exit(-1);
        }        
        ret = write(fd_tty, filebuf, n);
        if(ret == -1) {
            perror("uploadFile: error writing to fd_tty (2)");
            exit(-1);
        }

        address += n;
        n = read(fd, filebuf, sizeof filebuf);
        if(n == -1) {
            perror("uploadFile: error reading from fd");
            exit(-1);
        }
    }

    printf("uploaded %d bytes\n\r", address);

    close(fd);
}


void callAddress(int address) {
    char cmd_call[5];
    int ret;
    cmd_call[0] = 'C';
    assemble32(&cmd_call[1], 0);
    ret = write(fd_tty, cmd_call, sizeof cmd_call);
    if(ret == -1) {
        perror("callAddress: could not write to fd_tty");
        exit(-1);
    }
}

int readTestResult() {
    int tries = 500;

    while(tries--) {
        int n;
        char c;
        n = read(fd_tty, &c, 1);
        if(n > 0) {
            return (int)c;
        }
        usleep(1000);
    }

    return -2;
}

void console() {
    struct termios termcfg;
    tcgetattr(0, &termcfg);
    termcfg.c_lflag &= ~(ECHO | ICANON); // turn off echo, buffer
    tcsetattr(0, 0, &termcfg);

    // set stdin and fd_tty to non-blocking reads
    fcntl(0, F_SETFL, fcntl(0, F_GETFL) | O_NONBLOCK);
    fcntl(fd_tty, F_SETFL, fcntl(fd_tty, F_GETFL) | O_NONBLOCK);

    while(1) {
        int n, ret;
        char c;
        char active = 0;

        n = read(0, &c, 1);
        if(n > 0) {
            active = 1;
            ret = write(fd_tty, &c, 1);
            if(ret == -1) {
                perror("console: could not write to fd_tty");
                exit(-1);
            }
        }

        n = read(fd_tty, &c, 1);
        if(n > 0) {
            active = 1;
            ret = write(1, &c, 1);
            if(ret == -1) {
                perror("console: could not write to stdout");
                exit(-1);
            }
        }

        if(!active) {
            usleep(3 * 1000);
        }
    }

}

void drainfd() {
    char c;
    int n;
    int flags = fcntl(fd_tty, F_GETFL, 0);
    if(flags == -1) {
        perror("setting NONBLOCK failed");
	exit(-1);
    }
    flags |= O_NONBLOCK;
    int ret = fcntl(fd_tty, F_SETFL, flags);
    if(ret == -1) {
        perror("setting NONBLOCK failed");
	exit(-1);
    }
    do {
        n = read(fd_tty, &c, 1);
    } while(n > 0);
    ret = fcntl(fd_tty, F_SETFL, flags & ~O_NONBLOCK);
    if(ret == -1) {
        perror("setting ~NONBLOCK failed");
	exit(-1);
    }
}

int writeToSPI(char *data, char *response, int length) {
    drainfd();

    char op[1];
    char len[4];
    int ret;
    op[0] = 'S';
    assemble32(len, length);

    ret = write(fd_tty, op, sizeof op);
    if(ret == -1) {
        perror("writeToSPI: error writing to fd_tty (1)");
        exit(-1);
    }
    ret = write(fd_tty, len, sizeof len);
    if(ret == -1) {
        perror("writeToSPI: error writing to fd_tty (2)");
        exit(-1);
    }
    ret = write(fd_tty, data, length);
    if(ret == -1) {
        perror("writeToSPI: error writing to fd_tty (3)");
        exit(-1);
    }


    int received = 0;
    do {
        char recbuf[64];
        int n = read(fd_tty, recbuf, sizeof recbuf);
        if(n == -1) {
            perror("writeToSPI: error reading from fd_tty");
            exit(-1);
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
    exit(exitcode);
}

void sigint() {
    exit(exitcode);
}


int main(int argc, char *argv[])
{
    atexit(cleanup);
    signal(SIGINT, sigint);
    // save terminal state
    tcgetattr(0, &termsave);

    char *filename = NULL;
    char *portname = "/dev/ttyUSB1";
    if(access( portname, F_OK) == -1 ) {
        portname = "/dev/ttyUSB0";
    }
    
    char enterconsole = 0, program = 0, justReset = 0;


    int c;
    opterr = 0;

    while ((c = getopt (argc, argv, "rcd:f:pt")) != -1) {
        switch (c) {
            case 'r':
                justReset = 1;
                break;
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
            case 't':
                testrun = 1;
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


    printf("selected serial port: %s\n", portname);
    fd_tty = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd_tty < 0)
    {
        perror("error opening serial port");
        return 1;
    }
    set_interface_attribs(fd_tty, B115200);

    toggleReset();
    if(justReset) {
        if(!enterconsole) {
            return 0;
        } else {
            console();
        }
    }


    int fd_file = open (filename, O_RDONLY);
    if(fd_file == -1) {
        perror("could not open input file");
        return 1;
    }
    

    if(program) {
        enableWrite();
        eraseChip();
        printf("erasing chip...\n");
        while(isBusy()) {}
        printf("... aaaand it's gone!\n");
        printf("\n\r");
        printf("writing data...\n");
        programFile(filename);
        printf("... aaaand it's done!\n");
        printf("\n\r");
    } else {
        drainfd();
        uploadFile(filename, 0);
        callAddress(0);
    }

    if(testrun) {
        int result = readTestResult();
        if(result >= 0) {
            printf("TEST %d FAILED!\n\r", result);
            exitcode = 1;
        } else if(result == -1) {
            printf("TESTS PASSED!\n\r");
        } else if(result == -2) {
            printf("TESTS FAILED, READ TIMEOUT!\n\r");
            exitcode = 1;
        }

    } else if(enterconsole) {
        console();
    }


    return exitcode;
}
