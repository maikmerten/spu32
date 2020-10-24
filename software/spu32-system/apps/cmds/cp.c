#include <libtinyc.h>
#include "shared.h"

int do_cp(char* arg1, char* arg2)
{
    filehandle_t fh1;
    result_t res = bios_fs_open(&fh1, arg1, MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open input file\n\r");
        return 1;
    }

    filehandle_t fh2;
    res = bios_fs_open(&fh2, arg2, MODE_WRITE | MODE_CREATE_ALWAYS);
    if (res != RESULT_OK) {
        printf("could not open output file\n\r");
        bios_fs_close(fh1);
        return 1;
    }

    int returncode = 0;

    uint32_t read;
    char buf[8192];
    clear_buf(buf, sizeof(buf));
    res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    while (res == RESULT_OK && read > 0) {
        uint32_t written;
        result_t write_res = bios_fs_write(fh2, buf, read, &written);
        if (write_res != RESULT_OK) {
            printf("error writing to output file\n\r");
            returncode = 1;
            break;
        }
        res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    }

    bios_fs_close(fh1);
    bios_fs_close(fh2);

    return returncode;
}

int main(int argn, char** argv)
{
    return arg2_func(argn, argv, &do_cp);
}