#include <stdint.h>
#include <libtinyc.h>

int main(int argn, char** argv) {

    printf("This program will output its provided arguments. If the number of arguments is even, it'll return with an exit code of 0, 1 otherwise.\n\n\r");

    for(uint32_t i = 0; i < argn; ++i) {
        printf("argv[%d]: %s\n\r", i, argv[i]);
    }


    return argn & 0x1;
}