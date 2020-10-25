#include <libtinyc.h>
#include "shared.h"

int do_loadfont(char* arg0)
{
    int retcode = 0;
    result_t res;

    struct file_info_t fi;
    res = bios_fs_stat(arg0, &fi);
    if (fi.size != 4096) {
        printf("font file needs to be 4096 bytes\n");
        return 1;
    }

    filehandle_t fh;
    res = bios_fs_open(&fh, arg0, MODE_READ);
    if (res != RESULT_OK) {
        printf("error opening file\n");
        return 1;
    }

    videomode_t mode;
    void* videobase;
    void* fontbase;
    bios_video_get_mode(&mode, &videobase, &fontbase);

    uint32_t read;
    res = bios_fs_read(fh, fontbase, 4096, &read);
    if (res != RESULT_OK || read != 4096) {
        printf("error reading file\n");
        retcode = 1;
    }

    bios_fs_close(fh);

    return retcode;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_loadfont);
}