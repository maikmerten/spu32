#include <libtinyc.h>
#include "shared.h"

int do_sum(char* arg1)
{
    filehandle_t fh1;
    result_t res = bios_fs_open(&fh1, arg1, MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open input file\n\r");
        return 1;
    }

    
    uint32_t sum = 0;
    uint32_t read;
    char buf[8192];
    clear_buf(buf, sizeof(buf));
    res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    while (res == RESULT_OK && read > 0) {
        for(uint32_t i = 0; i < read; ++i) {
            sum = (sum >> 1) + ((sum & 1) << 15);
            sum += buf[i];
            sum &= 0xFFFF;
        }

        res = bios_fs_read(fh1, buf, sizeof(buf), &read);
    }

    bios_fs_close(fh1);
    printf("%d\n", sum);

    return 0;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_sum);
}