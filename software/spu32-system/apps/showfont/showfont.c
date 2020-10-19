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

    // skip a few lines
    text += (2*80) * 3;
    text += 8*2;

    for(int i = 0; i < 16; ++i) {
        int nextline = 2 * 80;
        for(int j = 0; j < 16; ++j) {
            *text = (char)((i << 4) | j);
            text += 4;
            nextline -= 4;
        }
        text += nextline;
    }

    
    return 0;
}