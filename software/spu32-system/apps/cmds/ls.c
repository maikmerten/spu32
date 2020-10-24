#include <libtinyc.h>
#include "shared.h"

void do_ls(int argn, char** argv)
{
    result_t res;

    char pattern[16];
    clear_buf(pattern, sizeof(pattern));
    if (argn < 2) {
        // no argument provided, search for *
        pattern[0] = '*';
    } else {
        strncat(pattern, argv[1], sizeof(pattern) - 1);
    }

    // List contents of current dir
    printf("\n\r");
    struct file_info_t finfo;
    res = bios_fs_findfirst(".", pattern, &finfo);
    while (res == RESULT_OK && finfo.name[0] != 0) {
        char padding[16];
        clear_buf(padding, sizeof(padding));
        uint32_t namelen = strlen(finfo.name);
        for (uint32_t i = 0; i < (sizeof(padding) - namelen); ++i) {
            padding[i] = ' ';
        }
        printf("%s", finfo.name);
        printf("%s %s   ", padding, (finfo.attrib & ATTRIB_DIR) != 0 ? "<DIR>" : "     ");
        printf("%d bytes\n\r", finfo.size);
        res = bios_fs_findnext(&finfo);
    }

    uint64_t free;
    res = bios_fs_free(&free);
    if (res == RESULT_OK) {
        uint32_t freekibi = free / 1024;
        uint32_t freemibi = freekibi / 1024;
        uint32_t freegibi = freemibi / 1024;
        printf("---\n\rfree: %d GiB, %d MiB, %d KiB\n\r", freegibi, freemibi, freekibi);
    } else {
        printf("could not determine number of free bytes\n\r");
    }

    printf("\n\r");
}

int main(int argn, char** argv)
{
    do_ls(argn, argv);
    return 0;
}