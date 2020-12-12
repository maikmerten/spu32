#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

#include "filesrv_shared.h"

int fd_tty;
int testrun = 0;
int exitcode = 0;

const int CHUNKSIZE = 64;

int set_interface_attribs(int fd, int speed)
{
    struct termios tty;
    memset(&tty, 0, sizeof tty);
    if (tcgetattr(fd, &tty) != 0) {
        perror("error from tcgetattr");
        return -1;
    }

    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    tty.c_cflag = (tty.c_cflag & ~CSIZE) | CS8; // 8-bit chars
    tty.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL | IXON | IXOFF | IXANY);
    tty.c_lflag = 0;
    tty.c_oflag = 0;

    tty.c_cflag |= (CLOCAL | CREAD); // ignore modem controls,
    tty.c_cflag &= ~(PARENB | PARODD | CSTOPB);

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        perror("error from tcsetattr");
        return -1;
    }
    return 0;
}

int read_func(void* buf, uint32_t len)
{
    uint32_t totalread = 0;
    uint32_t target = len;
    while (totalread != len) {
        int n = read(fd_tty, buf + totalread, target);
        totalread += n;
        target -= n;
    }
    return 0;
}

int write_func(void* buf, uint32_t len)
{
    int n = write(fd_tty, buf, len);
    return 0;
}

int dummy_payload_func(struct baseheader_t* header, void* payload) { }

int send_file(char* localpath, char* remotename)
{
    int error = 0;
    int fd = open(localpath, O_RDONLY);
    if (fd == -1) {
        perror("could not open input file");
        return 1;
    }

    int remotename_len = strlen(remotename);
    error = send_packet(FSERV_OPENWRITE, remotename, strlen(remotename), &read_func, &write_func);
    if (error) {
        printf("OPENWRITE failed\n");
        goto exit_send_file;
    }

    uint8_t buf[2048];
    int n = read(fd, buf, sizeof buf);
    while (n > 0) {
        printf(">");
        error = send_packet(FSERV_WRITE, buf, n, &read_func, &write_func);
        if (error) {
            printf("WRITE failed\n");
            goto exit_send_file;
        }
        n = read(fd, buf, sizeof buf);
    }

exit_send_file:
    printf("\n");
    close(fd);
    error = send_packet(FSERV_CLOSE, buf, 0, &read_func, &write_func);
    return error;
}

int receive_file(char* remotename, char* localpath)
{
    int error = 0;
    struct baseheader_t h;
    int n;

    int remotename_len = strlen(remotename);
    error = send_packet(FSERV_OPENREAD, remotename, strlen(remotename), &read_func, &write_func);
    if (error) {
        printf("OPENREAD failed\n");
        error = 2;
        goto exit_receive_file;
    }

    int fd = open(localpath, O_WRONLY | O_CREAT, 0644);
    if (fd == -1) {
        perror("could not open output file");
        return 1;
    }

    uint8_t buf[2048];
    int receive = 1;
    while (receive) {
        error = send_packet(FSERV_READ, buf, 0, &read_func, &write_func);
        if (error) {
            error = 3;
            goto exit_receive_file;
        }

        error = receive_packet(&h, buf, sizeof buf, &read_func, &write_func, &dummy_payload_func);
        if (error) {
            error = 4;
            goto exit_receive_file;
        }

        if (h.cmd == FSERV_DATA) {
            // write to local file
            if (h.payload_len == 0) {
                // end of file reached
                receive = 0;
            } else {
                printf(".");
                n = write(fd, buf, h.payload_len);
            }
        } else {
            // expected a DATA packet, got something else... eeeek!
            error = 5;
            goto exit_receive_file;
        }
    }

exit_receive_file:
    printf("\n");
    close(fd);
    send_packet(FSERV_CLOSE, buf, 0, &read_func, &write_func);
    return error;
}

int arg1_func(int argn, char** argv, int (*fun)(char*))
{
    if (argn < 2) {
        printf("needs an argument\n\r");
        return 1;
    }

    return (*fun)(argv[1]);
}

int arg2_func(int argn, char** argv, int (*fun)(char*, char*))
{
    if (argn < 3) {
        printf("needs two arguments\n\r");
        return 1;
    }

    return (*fun)(argv[1], argv[2]);
}

char* find_argument(char* inputbuf, size_t buflen, uint32_t n)
{
    uint32_t waswhitespace = 1;
    uint32_t current = 0;

    for (size_t i = 0; i < buflen; ++i) {
        char c = inputbuf[i];
        if (c == 0) {
            return NULL;
        }

        if (waswhitespace && c != ' ') {
            if (current == n) {
                return inputbuf + i;
            }
            waswhitespace = 0;
            current++;
        }

        if (c == ' ') {
            waswhitespace = 1;
        }
    }
}

void get_argument(char* buf, size_t buflen, uint32_t narg)
{
    buf[0] = 0;
    char* ptr = find_argument(buf, buflen, narg);
    if (ptr == NULL) {
        return;
    }

    for (size_t i = 0; i < (buflen - 1); ++i) {
        char c = ptr[i];
        if (c == 0 || c == ' ') {
            return;
        }
        buf[i] = c;
        buf[i + 1] = 0;
    }
}

uint32_t count_arguments(char* buf, size_t buflen)
{
    uint32_t n = 0;
    while (find_argument(buf, buflen, n) != NULL) {
        n++;
    }
    return n;
}

int cmdline()
{
    char buf[2048];
    char* bufptr = buf;
    size_t bufsize = sizeof(buf);

    while (1) {
        bufptr = buf;
        int read = getline(&bufptr, &bufsize, stdin);

        // clumsily replace newline
        for (size_t i = 0; i < sizeof(buf); i++) {
            if (buf[i] == '\n') {
                buf[i] = 0;
            }
        }

        uint32_t argn = count_arguments(buf, bufsize);
        if (argn > 0) {
            char* argv[argn];
            for (uint32_t i = 0; i < argn; ++i) {
                argv[i] = find_argument(buf, bufsize, i);
            }

            // clumsily replace space
            for (size_t i = 0; i < sizeof(buf); i++) {
                if (buf[i] == ' ') {
                    buf[i] = 0;
                }
            }

            char* arg0 = argv[0];
            printf("'%s'\n", arg0);

            if (strcmp(arg0, "exit") == 0) {
                return 0;
            } else if (strcmp(arg0, "help") == 0) {
                printf("This is the help command being helpful: You can do it!\n");
            } else if (strcmp(arg0, "get") == 0) {
                arg2_func(argn, argv, &receive_file);
            } else if (strcmp(arg0, "put") == 0) {
                arg2_func(argn, argv, &send_file);
            } else {
                printf("Unknown command. Use 'help', please.\n");
            }
        }
    }

    return 0;
}

int exit_filesrv()
{
    int error = 0;
    error = send_packet(FSERV_EXIT, (void*)&error, 0, &read_func, &write_func);
    return error;
}

void cleanup()
{
    close(fd_tty);
    printf("bye.\n\r");
    exit(exitcode);
}

void sigint()
{
    exit(exitcode);
}

int main(int argc, char* argv[])
{
    atexit(cleanup);
    signal(SIGINT, sigint);

    char* filename = "send.dat";
    char* portname = "/dev/ttyUSB1";
    if (access(portname, F_OK) == -1) {
        portname = "/dev/ttyUSB0";
    }

    int c;
    opterr = 0;

    while ((c = getopt(argc, argv, "d:f:")) != -1) {
        switch (c) {
        case 'd':
            portname = optarg;
            break;
        case 'f':
            filename = optarg;
            break;
        case '?':
            if (optopt == 'd' || optopt == 'f') {
                fprintf(stderr, "Option -%c requires an argument.\n", optopt);
            } else if (isprint(optopt)) {
                fprintf(stderr, "Unknown option `-%c'.\n", optopt);
            } else {
                fprintf(stderr, "Unknown option character `\\x%x'.\n", optopt);
            }
            return 1;
        default:
            abort();
        }
    }

    // command to prevent control line change (reset!) on device open:
    // stty -F /dev/ttyUSB1 -hupcl

    printf("selected serial port: %s\n", portname);
    fd_tty = open(portname, O_RDWR | O_NOCTTY | O_SYNC);
    if (fd_tty < 0) {
        perror("error opening serial port");
        return 1;
    }
    set_interface_attribs(fd_tty, B115200);

    /*
    if (1) {
        int error = send_file(filename, "receive.dat");
        if (error) {
            printf("send_file failed\n");
        }
    } else {
        int error = receive_file("receive.dat", "receive.dat"); // local dest, remote src
    }
*/

    //exit_filesrv();
    cmdline();

    return exitcode;
}
