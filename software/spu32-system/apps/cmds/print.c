#include <libtinyc.h>
#include "shared.h"

int do_print(char* arg1)
{
    filehandle_t fh;
    result_t res = bios_fs_open(&fh, arg1, MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open input file\n\r");
        return 1;
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
        return 1;
    }
    return 0;
}


int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_print);
}