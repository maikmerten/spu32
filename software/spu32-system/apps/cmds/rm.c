#include <libtinyc.h>
#include "shared.h"

int do_rm(char* arg1)
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
    return 0;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_rm);
}