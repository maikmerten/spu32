#include <libtinyc.h>
#include <stdint.h>

// fixed point precision, bits for fractional part
const uint32_t SHIFT = 24;
const uint32_t PIXELS_X = 320;
const uint32_t PIXELS_Y = 240;

void setVideoMode(uint8_t* framebuf)
{

    // clear framebuffer
    for(int i = 0; i < (PIXELS_X * PIXELS_Y); ++i) {
        framebuf[i] = 0;
    }

    uint8_t palette[256 * 3];
    for(int i = 0; i < 256; i++) {
        uint8_t r, g, b;
        if(i == 0) {
            r = g = b = 0;
        } else {
            r = (i + 64) & 0xFF;
            g = (i + 128) & 0xFF;
            b = (i + 192) & 0xFF;
        }

        palette[i * 3] = r;
        palette[i * 3 + 1] = g;
        palette[i * 3 + 2] = b;
    }
    bios_video_set_palette(palette);

    videomode_t mode;
    void* videobase;
    void* fontbase;

    bios_video_get_mode(&mode, &videobase, &fontbase);
    mode = VIDEOMODE_GRAPHICS_320;
    videobase = framebuf;

    bios_video_set_mode(mode, videobase, fontbase);
}

// originally based on https://rosettacode.org/wiki/Mandelbrot_set#B
void renderMandel(int32_t xmin, int32_t dx, int32_t ymin, int32_t dy, uint32_t maxiter, uint8_t* framebuf)
{

    int32_t cy = ymin;
    for (int32_t ypos = 0; ypos < PIXELS_Y; ++ypos) {
        int32_t cx = xmin;
        for (int32_t xpos = 0; xpos < PIXELS_X; ++xpos) {
            int32_t x = 0;
            int32_t y = 0;
            int32_t x2 = 0;
            int32_t y2 = 0;
            int32_t iter = 0;

            while (iter < maxiter) {
                if (x2 + y2 > (4 << SHIFT))
                    break;

                // prescale multiplicants to ensure result fits in int32_t
                int32_t x_scaled = x >> (SHIFT / 2);
                int32_t y_scaled = y >> (SHIFT / 2);
                y = x_scaled * y_scaled;
                y += y; // times two
                y += cy;

                x = (x2 - y2) + cx;

                x_scaled = x >> (SHIFT / 2);
                x2 = x_scaled * x_scaled;

                y_scaled = y >> (SHIFT / 2);
                y2 = (y_scaled * y_scaled);

                iter++;
            }

            *framebuf++ = (uint8_t)(iter & 0xFF);
            cx += dx;
        }
        //printf("\n\r");
        cy += dy;
    }
}

int main()
{

    const double xmin_d = -2.09;
    const double xmax_d = 0.7;
    const double ymin_d = -1.2;
    const double ymax_d = 1.2;

    const int32_t xmin = (int32_t)(xmin_d * (1 << SHIFT));
    const int32_t ymin = (int32_t)(ymin_d * (1 << SHIFT));

    const int32_t dx = (int32_t)((xmax_d - xmin_d) / (PIXELS_X - 1) * (1 << SHIFT));
    const int32_t dy = (int32_t)((ymax_d - ymin_d) / (PIXELS_Y - 1) * (1 << SHIFT));

    const int32_t maxiter = 256;

    // create and clear framebuffer
    uint8_t framebuf[PIXELS_X * PIXELS_Y];
 
    setVideoMode(framebuf);
    renderMandel(xmin, dx, ymin, dy, maxiter, framebuf);

    // wait for input, then exit
    char buf[2];
    read_string(buf, sizeof(buf), 1);

    return (0);
}