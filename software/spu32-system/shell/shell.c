#include "../bios/devices.h"
#include <libtinyc.h>
#include <stdint.h>

char inputbuf[128];

void load_color_palette()
{
    static uint8_t default_palette[8][3] = {
        { 0, 0, 0 }, // black
        { 200, 0, 0 }, // red
        { 0, 200, 0 }, // green
        { 200, 200, 0 }, // yellow
        { 0, 0, 200 }, // blue
        { 200, 0, 200 }, // magenta
        { 0, 200, 200 }, // cyan
        { 200, 200, 200 } // "white"
    };

    uint8_t palette[256 * 3];
    uint32_t basecolor = 0;

    for (uint32_t idx = 0; idx < sizeof(palette); idx += 3) {
        palette[idx] = default_palette[basecolor][0];
        palette[idx + 1] = default_palette[basecolor][1];
        palette[idx + 2] = default_palette[basecolor][2];

        basecolor++;
        basecolor &= 0b0111;
    }

    bios_video_set_palette(palette);
}

void clear_buf(char* buf, uint32_t len)
{
    for (uint32_t i = 0; i < len; ++i) {
        buf[i] = 0;
    }
}

void read_input()
{
    inputbuf[0] = 0;

    char cwd[64];
    bios_fs_getcwd(cwd, sizeof(cwd));

    uint8_t execute = 0;
    uint32_t bufidx = 0;

    printf("%s $ %s", cwd, inputbuf);

    while (!execute) {
        char c;
        bios_stream_read(DEVICE_STDIN, &c, 1);
        if (c == '\n' || c == '\r') {
            execute = 1;
        } else if (c == 127) {
            if (bufidx > 0) {
                inputbuf[--bufidx] = 0;
                printf("\b \b");
            }
        } else if (c < 32) {
            // ignore other control characters
        } else if (bufidx < (sizeof(inputbuf) - 1)) {
            inputbuf[bufidx] = c;
            inputbuf[bufidx + 1] = 0;
            bufidx++;
            printf("%c", c);
        }
    }

    printf("\n\r");
}

char* find_argument(uint32_t n)
{
    uint32_t waswhitespace = 1;
    uint32_t current = 0;

    for (uint32_t i = 0; i < sizeof(inputbuf); ++i) {
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

void get_argument(char* buf, uint32_t buflen, uint32_t narg)
{
    buf[0] = 0;
    char* ptr = find_argument(narg);
    if (ptr == NULL) {
        return;
    }

    for (uint32_t i = 0; i < (buflen - 1); ++i) {
        char c = ptr[i];
        if (c == 0 || c == ' ') {
            return;
        }
        buf[i] = c;
        buf[i + 1] = 0;
    }
}

uint32_t count_arguments()
{
    uint32_t n = 0;
    while (find_argument(n) != NULL) {
        n++;
    }
    return n;
}

void arg1_func(void (*fun)(char*))
{
    char arg1[64];

    get_argument(arg1, sizeof(arg1), 1);
    if (arg1[0] == 0) {
        printf("needs an argument\n\r");
        return;
    }

    (*fun)(arg1);
}

void arg2_func(void (*fun)(char*, char*))
{
    char arg1[64];
    char arg2[64];

    get_argument(arg1, sizeof(arg1), 1);
    get_argument(arg2, sizeof(arg2), 2);
    if (arg1[0] == 0 || arg2[0] == 0) {
        printf("needs two arguments\n\r");
        return;
    }

    (*fun)(arg1, arg2);
}

void do_ls()
{
    result_t res;

    char pattern[16];
    clear_buf(pattern, sizeof(pattern));
    get_argument(pattern, 16, 1);
    if (pattern[0] == 0) {
        // no argument provided, search for *
        pattern[0] = '*';
    }

    // List contents of current dir
    printf("\n\r");
    struct file_info_t finfo;
    res = bios_fs_findfirst(".", pattern, &finfo);
    while (res == RESULT_OK && finfo.name[0] != 0) {
        char padding[16];
        clear_buf(padding, sizeof(padding));
        uint32_t namelen = strlen(finfo.name);
        for (uint32_t i = 0; i < (sizeof(padding) - namelen); ++i) {
            padding[i] = ' ';
        }
        printf("%s", finfo.name);
        printf("%s %s   ", padding, (finfo.attrib & ATTRIB_DIR) != 0 ? "<DIR>" : "     ");
        printf("%d bytes\n\r", finfo.size);
        res = bios_fs_findnext(&finfo);
    }

    uint64_t free;
    res = bios_fs_free(&free);
    if (res == RESULT_OK) {
        uint32_t freekibi = free / 1024;
        uint32_t freemibi = freekibi / 1024;
        uint32_t freegibi = freemibi / 1024;
        printf("---\n\rfree: %d GiB, %d MiB, %d KiB\n\r", freegibi, freemibi, freekibi);
    } else {
        printf("could not determine number of free bytes\n\r");
    }

    printf("\n\r");
}

void do_mkdir(char* arg1)
{
    result_t res = bios_fs_mkdir(arg1);
    if (res != RESULT_OK) {
        printf("could not make directory %s\n\r", arg1);
    }
}

void do_rm(char* arg1)
{
    struct file_info_t finfo;
    result_t res = bios_fs_findfirst(".", arg1, &finfo);
    while (res == RESULT_OK && finfo.name[0] != 0) {
        result_t unlink_res = bios_fs_unlink(finfo.name);
        if (unlink_res != RESULT_OK) {
            printf("could not remove %s\n\r", finfo.name);
        }
        res = bios_fs_findnext(&finfo);
    }
}

void do_cd(char* arg1)
{
    result_t res = bios_fs_chdir(arg1);
    if (res != RESULT_OK) {
        printf("could not change directory to %s\n\r", arg1);
    }
}

void do_mv(char* arg1, char* arg2)
{
    result_t res = bios_fs_rename(arg1, arg2);
    if (res != RESULT_OK) {
        printf("could not rename %s\n\r", arg1);
    }
}

void do_print(char* arg1)
{
    filehandle_t fh;
    result_t res = bios_fs_open(&fh, arg1, MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open input file\n\r");
        return;
    }

    uint32_t read;
    char buf[512];
    clear_buf(buf, sizeof(buf));
    res = bios_fs_read(fh, buf, sizeof(buf), &read);
    while (res == RESULT_OK && read > 0) {
        printf("%s", buf);
        clear_buf(buf, sizeof(buf));
        res = bios_fs_read(fh, buf, sizeof(buf), &read);
    }

    res = bios_fs_close(fh);
    if (res != RESULT_OK) {
        printf("could not close file\n\r");
    }
}

int do_run(char* arg0, char in_bin)
{

    uint32_t arglen = strlen(arg0);
    char buf[5 + arglen + 5];
    clear_buf(buf, sizeof buf);
    char* prgfile = buf;

    // prepend "/bin/" prefix
    strcpy(prgfile, "/bin/");

    // copy in binary name
    strcpy(prgfile + 5, arg0);

    // append ".bin" suffix;
    strcpy(prgfile + 5 + arglen, ".bin");

    if (!in_bin) {
        // skip "/bin/" prefix if not searching in /bin
        prgfile += 5;
    }

    uint32_t error = 0;
    filehandle_t fh;
    result_t res = bios_fs_open(&fh, prgfile, MODE_READ);
    if (res != RESULT_OK) {
        return 1;
    }

    uint32_t maxbytes = (512 - 64) * 1024;

    uint32_t size;
    res = bios_fs_size(fh, &size);
    if (size > maxbytes) {
        printf("%s is %d bytes, only up to %d bytes allowed\n\r", prgfile, size, maxbytes);
        bios_fs_close(fh);
        return 1;
    }

    uint32_t read;
    void* loadaddr = (void*)0x0;
    res = bios_fs_read(fh, loadaddr, maxbytes, &read);
    if (res != RESULT_OK) {
        printf("error reading file %s\n\r", prgfile);
        error = 1;
    }

    res = bios_fs_close(fh);
    if (res != RESULT_OK) {
        printf("could not close file\n\r");
        error = 1;
    }

    if (!error) {
        uint32_t (*program)(uint32_t nargs, char** argv) = (void*)loadaddr;

        uint32_t argn = count_arguments();

        // create array of pointers to program argument strings
        char* argv[argn];
        for (uint32_t i = 0; i < argn; ++i) {
            argv[i] = find_argument(i);
        }

        // null-terminate arguments in buffer
        for (uint32_t i = 0; i < sizeof(inputbuf); ++i) {
            if (inputbuf[i] == ' ') {
                inputbuf[i] = 0;
            }
        }

        uint32_t exitcode = (*program)(argn, argv);

        if(exitcode != 0) {
            printf("\n\rexit code: %d\n\r", exitcode);
        }
        printf("\n");
    }
    return error;
}

void do_cp(char* arg1, char* arg2)
{
    filehandle_t fh1;
    result_t res = bios_fs_open(&fh1, arg1, MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open input file\n\r");
        return;
    }

    filehandle_t fh2;
    res = bios_fs_open(&fh2, arg2, MODE_WRITE | MODE_CREATE_ALWAYS);
    if (res != RESULT_OK) {
        printf("could not open output file\n\r");
        bios_fs_close(fh1);
        return;
    }

    uint32_t read;
    char buf[8192];
    clear_buf(buf, sizeof(buf));
    res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    while (res == RESULT_OK && read > 0) {
        uint32_t written;
        result_t write_res = bios_fs_write(fh2, buf, read, &written);
        if (write_res != RESULT_OK) {
            printf("error writing to output file\n\r");
            break;
        }
        res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    }

    bios_fs_close(fh1);
    bios_fs_close(fh2);
}

void execute_input()
{
    char arg0[16];
    uint32_t narg = count_arguments();
    if (narg == 0) {
        return;
    }
    get_argument(arg0, sizeof(arg0), 0);
    if (!do_run(arg0, 1)) {
        // executed program from /bin
    } else if (strcmp(arg0, "ls") == 0 || strcmp(arg0, "dir") == 0) {
        do_ls();
    } else if (strcmp(arg0, "mkdir") == 0) {
        arg1_func(&do_mkdir);
    } else if (strcmp(arg0, "rm") == 0) {
        arg1_func(&do_rm);
    } else if (strcmp(arg0, "cd") == 0) {
        arg1_func(&do_cd);
    } else if (strcmp(arg0, "mv") == 0) {
        arg2_func(&do_mv);
    } else if (strcmp(arg0, "print") == 0) {
        arg1_func(&do_print);
    } else if (strcmp(arg0, "cp") == 0) {
        arg2_func(&do_cp);
    } else {
        if (do_run(arg0, 0)) {
            printf("could not execute %s\n\r", arg0);
        }
    }
}

/**
 * The main entry point to the shell
 */
int main()
{
    uint8_t fontdat[2048];
    uint8_t videodat[(40 * 30) * 2]; // 40 cols, 30 cols, 2 bytes per character (char, colour)

    // load font file
    filehandle_t fh;
    result_t res = bios_fs_open(&fh, "/font.dat", MODE_READ);
    if (res == RESULT_OK) {
        // read font data
        uint32_t read;
        res = bios_fs_read(fh, &fontdat, sizeof fontdat, &read);
        if (res != RESULT_OK) {
            printf("could not read /font.dat\n\r");
        }
        bios_fs_close(fh);

        // clear video text buffer;
        for (uint32_t i = 0; i < sizeof videodat; i += 2) {
            videodat[i] = '@';
            // set fg colour to light gray, bg colour to black
            videodat[i + 1] = 0x70;
        }

        bios_video_set_mode(VIDEOMODE_TEXT_40, &videodat, &fontdat);

    } else {
        printf("could not load /font.dat\n\r");
    }

    load_color_palette();

    printf("\n\r\n\rSPU32 Shell 0.0.1\n\r");

    while (1) {
        read_input();
        execute_input();
        load_color_palette();
    }

    return 0;
}
