#include "shared.h"
#include <libtinyc.h>

int main(int argn, char** argv)
{
    videomode_t mode;
    void* videobase;
    void* fontbase;

    bios_video_get_mode(&mode, &videobase, &fontbase);

    // reinit video mode, trigger display clear
    bios_video_set_mode(mode, videobase, fontbase);
}