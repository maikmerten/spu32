#include <libtinyc.h>
#include "shared.h"

int do_mv(char* arg1, char* arg2)
{
    result_t res = bios_fs_rename(arg1, arg2);
    if (res != RESULT_OK) {
        printf("could not rename %s\n\r", arg1);
        return 1;
    }
    return 0;
}


int main(int argn, char** argv)
{
    return arg2_func(argn, argv, &do_mv);
}