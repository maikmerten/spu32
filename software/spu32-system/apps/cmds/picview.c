#include <libtinyc.h>
#include "shared.h"

#define PICSIZE 86400

int do_picview(char* arg0)
{
    int retcode = 0;
    result_t res;

    struct file_info_t fi;
    res = bios_fs_stat(arg0, &fi);
    if (fi.size != PICSIZE) {
        printf("picture file needs to be PICSIZE bytes\n");
        return 1;
    }

    filehandle_t fh;
    res = bios_fs_open(&fh, arg0, MODE_READ);
    if (res != RESULT_OK) {
        printf("error opening file\n");
        return 1;
    }

    // allocate framebuffer on stack
    uint8_t framebuffer[PICSIZE];
    if(((uint32_t) &framebuffer[0]) & 0x1) {
        printf("frambuffer unaligned\n");
        return 1;
    }

    videomode_t mode;
    void* videobase;
    void* fontbase;
    bios_video_get_mode(&mode, &videobase, &fontbase);

    mode = VIDEOMODE_COMPRESSED_640;
    videobase = &framebuffer[0];

    bios_video_set_mode(mode, videobase, fontbase);

    uint32_t read = 0;
    res = bios_fs_read(fh, framebuffer, sizeof(framebuffer), &read);
    if (res != RESULT_OK) {
        printf("error reading file\n");
        retcode = 1;
    }


    bios_fs_close(fh);

    // wait for input, then exit
    char buf[2];
    read_string(buf, sizeof(buf), 1);

    return retcode;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_picview);
}