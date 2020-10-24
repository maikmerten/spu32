#include "shared.h"
#include <libtinyc.h>

void clear_buf(char* buf, int len)
{
    for (int i = 0; i < len; ++i) {
        buf[i] = 0;
    }
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
