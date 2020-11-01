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

int do_run(char* arg0, char in_bin, int* exitcode)
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

        *exitcode = (*program)(argn, argv);
    }
    return error;
}

int execute_input()
{
    char arg0[16];
    uint32_t narg = count_arguments();
    if (narg == 0) {
        return 0;
    }

    int exitcode = 0;
    get_argument(arg0, sizeof(arg0), 0);
    if (!do_run(arg0, 1, &exitcode)) {
        // executed program from /bin
    } else {
        if (do_run(arg0, 0, &exitcode)) {
            printf("could not execute %s\n\r", arg0);
        }
    }
    return exitcode;
}

/**
 * The main entry point to the shell
 */
int main()
{
    uint8_t fontdat[4096];
    uint8_t videodat[(80 * 30) * 2]; // 80 cols, 30 rows, 2 bytes per character (char, colour)

    // load font file
    filehandle_t fh;
    result_t res = bios_fs_open(&fh, "/font80.dat", MODE_READ);
    if (res == RESULT_OK) {
        // read font data
        uint32_t read;
        res = bios_fs_read(fh, &fontdat, sizeof fontdat, &read);
        if (res != RESULT_OK) {
            printf("could not read /font80.dat\n\r");
        }
        bios_fs_close(fh);

        // clear video text buffer;
        for (uint32_t i = 0; i < sizeof videodat; i += 2) {
            videodat[i] = '@';
            // set fg colour to light gray, bg colour to black
            videodat[i + 1] = 0x70;
        }

        bios_video_set_mode(VIDEOMODE_TEXT_80, &videodat, &fontdat);

    } else {
        printf("could not load /font80.dat\n\r");
    }

    load_color_palette();

    printf("\n\r\n\rSPU32 Shell 0.0.1\n\r");

    while (1) {
        read_input();
        int exitcode = execute_input();

        videomode_t videomode;
        void* videobase;
        void* fontbase;
        bios_video_get_mode(&videomode, &videobase, &fontbase);
        if(videomode != VIDEOMODE_TEXT_80) {
            bios_video_set_mode(VIDEOMODE_TEXT_80, &videodat, &fontdat);
        }
        load_color_palette();

        if(exitcode) {
            printf("\nexit code: %d\n", exitcode);
        }

    }

    return 0;
}
