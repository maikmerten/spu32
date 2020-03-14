/**
 * This is an attempt to create a bootloader for the SD card.
 */
#include "../bios/devices.h"
#include <libtinyc.h>
#include <stdint.h>

#define LED *((volatile uint8_t*)DEV_LED)

#define ERR_INIT 1
#define ERR_OPEN 2
#define ERR_WRITE 3
#define ERR_READ 4
#define ERR_CLOSE 5
#define ERR_SIZE 6
#define ERR_TOOBIG 7

int main();
void halt(uint8_t error);


/**
 * The main entry point to the bootloader.
 */
int main()
{
    filehandle_t fh;
    LED = 0xAA;

    printf("Bootloader stage 2 active...\n\n\r"); // Greet the user

    // Mounting file system

    result_t res = bios_fs_init(DEVICE_SD);
    if (res != RESULT_OK) {
        printf("could not mount FAT file system, halting.\n\r");
        halt(ERR_INIT);
    }


    // Reading shell.bin
    res = bios_fs_open(&fh, "shell.bin", MODE_READ);
    if (res != RESULT_OK) {
        printf("error opening shell.bin, halting.\n\r");
        halt(ERR_OPEN);
    }

    printf("successfully opened shell.bin\n\r");

    // check size of shell
    uint32_t size;
    res = bios_fs_size(fh, &size);
    if (res != RESULT_OK) {
        printf("error determining size of shell.bin, halting.\n\r");
        halt(ERR_SIZE);
    }

    if(size > 8192) {
        printf("shell.bin is %d bytes, must not be bigger than 8192 bytes, halting.\n\r");
        halt(ERR_TOOBIG);
    }

    printf("size of shell.bin is %d bytes\n\r", size);


    void* buf = (void*)((512 - 40) * 1024);

    uint32_t read;
    res = bios_fs_read(fh, buf, 8 * 1024, &read);
    if (res != RESULT_OK) {
        printf("error reading shell.bin, halting.\n\r");
        halt(ERR_READ);
    }

    printf("did read %d bytes\n\r", read);

    res = bios_fs_close(fh);
    if (res == RESULT_OK) {
        printf("closed shell.bin\n\r");
    } else {
        printf("could not close shell.bin, halting.\n\r");
        halt(ERR_CLOSE);
    }


    printf("Exiting bootloader, starting shell...\n\r");

    LED = 0;
    return 0;
}

void halt(uint8_t error)
{
    LED = error;
    while (1) {
    }
}