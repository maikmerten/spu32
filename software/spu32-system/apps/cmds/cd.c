#include <libtinyc.h>
#include "shared.h"

int do_cd(char* arg1)
{
    result_t res = bios_fs_chdir(arg1);
    if (res != RESULT_OK) {
        printf("could not change directory to %s\n\r", arg1);
        return 1;
    }
    return 0;
}


int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_cd);
}