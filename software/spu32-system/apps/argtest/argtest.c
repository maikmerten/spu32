#include <stdint.h>
#include <libtinyc.h>

int main(char** args, uint32_t nargs) {

    printf("This program will output its provided arguments. If the number of arguments is even, it'll return with an exit code of 0, 1 otherwise.\n\n\r");

    for(uint32_t i = 0; i < nargs; ++i) {
        printf("argument %d: %s\n\r", i, args[i]);
    }


    return nargs & 0x1;
}