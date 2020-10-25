#include <libtinyc.h>

int main(int argn, char** argv) {

    const char hex[] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};

    videomode_t mode;
    void* videobase;
    void* fontbase;
    bios_video_get_mode(&mode, &videobase, &fontbase);

    char* text = (char*)videobase;

    // clear screen, online, fast
    for(int i = 0; i < 32; ++i) {
        printf("\n");
    }

    const int ROWBYTES = 2 * 80;
    const int COLBYTES = 2;

    // print column header
    int offset = (1 * ROWBYTES) + (6 * COLBYTES);
    for(int i = 0; i < 16; ++i) {
        text[(i * 2 * COLBYTES) + offset] = hex[i];
    }

    // print row header
    offset = (3 * ROWBYTES) + (2 * COLBYTES);
    for(int i = 0; i < 16; ++i) {
        text[(i * ROWBYTES) + offset] = hex[i];
    }

    // print 256 font characters in 16x16 grid
    offset = (3 * ROWBYTES) + (6 * COLBYTES);
    for(int i = 0; i < 16; ++i) {
        for(int j = 0; j < 16; ++j) {
            text[(i * ROWBYTES) + (j * 2 * COLBYTES) + offset] = (char)((i << 4) | j);
        }
    }

    
    return 0;
}