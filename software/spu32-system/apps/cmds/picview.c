#include <libtinyc.h>
#include "shared.h"

#define PICSIZE 86400

int load_pic(char* filename, int32_t subpicture, uint8_t* framebuffer, uint32_t framebuffer_size)
{

    filehandle_t fh;
    result_t res = bios_fs_open(&fh, filename, MODE_READ);
    if (res != RESULT_OK) {
        printf("error opening file\n");
        return 1;
    }

    res = bios_fs_seek(fh, PICSIZE * subpicture);
    if(res != RESULT_OK) {
        printf("seek failed\n");
        bios_fs_close(fh);
        return 1;
    }


    uint32_t read = 0;
    res = bios_fs_read(fh, framebuffer, framebuffer_size, &read);
    if (res != RESULT_OK) {
        printf("error reading file\n");
        bios_fs_close(fh);
        return 1;
    }

    bios_fs_close(fh);
    return 0;
}


int do_picview(char* arg0)
{
    int retcode = 0;
    result_t res;

    struct file_info_t fi;
    res = bios_fs_stat(arg0, &fi);
    if (fi.size % PICSIZE != 0) {
        printf("file size needs to multiple of % bytes\n", PICSIZE);
        return 1;
    }

    int32_t subpics = fi.size / PICSIZE;

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

    int32_t subpic = 0;
    uint8_t run = 1;
    do {
        if(subpic >= subpics) {
            subpic = subpics - 1; 
        } else if(subpic < 0) {
            subpic = 0;
        }

        retcode = load_pic(arg0, subpic, framebuffer, sizeof(framebuffer));
        if(retcode) {
            break;
        }

        char c;
        bios_stream_read(DEVICE_STDIN, &c, 1);

        switch(c) {
            case '+':
            case ' ':
            case 'n': {
                subpic++;
                break;
            }

            case 127: // backspace
            case '-':
            case 'p': {
                subpic--;
                break;
            }

            case 'q':
            case 'x': {
                run = 0;
                break;
            }
        }

    } while(run);


    return retcode;
}

int main(int argn, char** argv)
{
    return arg1_func(argn, argv, &do_picview);
}