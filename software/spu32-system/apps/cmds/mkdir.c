#include <libtinyc.h>
#include "shared.h"

int do_mkdir(char* arg1)
{
    result_t res = bios_fs_mkdir(arg1);
    if (res != RESULT_OK) {
        printf("could not make directory %s\n\r", arg1);
        return 1;
    }

    return 0;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_mkdir);
}