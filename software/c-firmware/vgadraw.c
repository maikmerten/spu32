#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>
#include "../asm/devices.h"

#define VGA_BASE *((volatile uint32_t*)DEV_VGA_BASE)
#define VGA_MODE *((volatile uint8_t*)DEV_VGA_MODE)

const int screenwidth = 320;
const int screenheight = 240;

int16_t clipxmin = 0;
int16_t clipxmax = screenwidth - 1;
int16_t clipymin = 0;
int16_t clipymax = screenheight - 1;

uint32_t vgabase = (32*1024);

void setVGABase(uint32_t baseadr) {
    vgabase = baseadr;
    printf("vga base: %d\n\r", vgabase);
}

void switchVGABase() {
    // switch to 320x240 graphics mode
    VGA_MODE = 3;
    VGA_BASE = vgabase;
}


void setClip(int16_t xmin, int16_t xmax, int16_t ymin, int16_t ymax) {
    clipxmin = xmin;
    clipxmax = xmax;
    clipymin = ymin;
    clipymax = ymax;
}

uint32_t inline __attribute__((always_inline)) packColor(uint8_t color) {
    uint32_t packed_color = color;
    packed_color = (packed_color << 8) | color;
    packed_color = (packed_color << 8) | color;
    packed_color = (packed_color << 8) | color;
    return packed_color;
}


void inline __attribute__((always_inline)) drawPixel(int16_t x, int16_t y, uint8_t color) {
    if(x < clipxmin || x > clipxmax || y < clipymin || y > clipymax) {
        return;
    }

    uint32_t offset = (y * 320) + x;
    *((uint8_t*)(vgabase+offset)) = color;
}

void drawHLine(int16_t x, int16_t y, uint16_t pixels, uint32_t packed_color) {
    if(x > clipxmax || y < clipymin || y > clipymax) {
        return;
    }
    int16_t endx = x + (pixels - 1);
    if(endx < clipxmin) {
        return;
    }
    if(endx > clipxmax) {
        endx = clipxmax;
    }
    if(x < clipxmin) {
        x = clipxmin;
    }

    pixels = endx - x + 1;

    uint32_t adr = (vgabase + ((y * 320) + x));

    while(pixels >= 32) {
        *((uint32_t*)adr) = packed_color;
        *((uint32_t*)(adr + 4)) = packed_color;
        *((uint32_t*)(adr + 8)) = packed_color;
        *((uint32_t*)(adr + 12)) = packed_color;
        *((uint32_t*)(adr + 16)) = packed_color;
        *((uint32_t*)(adr + 20)) = packed_color;
        *((uint32_t*)(adr + 24)) = packed_color;
        *((uint32_t*)(adr + 28)) = packed_color;
        adr += 32;
        pixels -= 32;
    }

    while(pixels >= 16) {
        *((uint32_t*)adr) = packed_color;
        *((uint32_t*)(adr + 4)) = packed_color;
        *((uint32_t*)(adr + 8)) = packed_color;
        *((uint32_t*)(adr + 12)) = packed_color;
        adr += 16;
        pixels -= 16;
    }

    while(pixels >= 4) {
        *((uint32_t*)adr) = packed_color;
        adr += 4;
        pixels -= 4;
    }

    while(pixels >= 2) {
        *((uint16_t*)adr) = packed_color;
        adr += 2;
        pixels -= 2;
    }

    while(pixels > 0) {
        *((uint8_t*)adr) = packed_color;
        adr++;
        pixels--;
    }
}


void drawHLinePreclipped(int16_t x, int16_t y, uint16_t pixels, int32_t packed_color) {

    int16_t endx = x + (pixels - 1);
    pixels = endx - x + 1;

    uint32_t adr = (vgabase + ((y * 320) + x));

    while(pixels >= 32) {
        *((uint32_t*)adr) = packed_color;
        *((uint32_t*)(adr + 4)) = packed_color;
        *((uint32_t*)(adr + 8)) = packed_color;
        *((uint32_t*)(adr + 12)) = packed_color;
        *((uint32_t*)(adr + 16)) = packed_color;
        *((uint32_t*)(adr + 20)) = packed_color;
        *((uint32_t*)(adr + 24)) = packed_color;
        *((uint32_t*)(adr + 28)) = packed_color;
        adr += 32;
        pixels -= 32;
    }

    while(pixels >= 16) {
        *((uint32_t*)adr) = packed_color;
        *((uint32_t*)(adr + 4)) = packed_color;
        *((uint32_t*)(adr + 8)) = packed_color;
        *((uint32_t*)(adr + 12)) = packed_color;
        adr += 16;
        pixels -= 16;
    }

    while(pixels >= 4) {
        *((uint32_t*)adr) = packed_color;
        adr += 4;
        pixels -= 4;
    }

    while(pixels >= 2) {
        *((uint16_t*)adr) = packed_color;
        adr += 2;
        pixels -= 2;
    }

    while(pixels > 0) {
        *((uint8_t*)adr) = packed_color;
        adr++;
        pixels--;
    }

}


void fillScreen(uint8_t color) {
    uint32_t packed_color = packColor(color);

    uint32_t adr = vgabase;
    while(adr < (vgabase + (screenwidth * screenheight))) {
        *((uint32_t*)adr) = packed_color;
        *((uint32_t*)(adr + 4)) = packed_color;
        *((uint32_t*)(adr + 8)) = packed_color;
        *((uint32_t*)(adr + 12)) = packed_color;
        *((uint32_t*)(adr + 16)) = packed_color;
        *((uint32_t*)(adr + 20)) = packed_color;
        *((uint32_t*)(adr + 24)) = packed_color;
        *((uint32_t*)(adr + 28)) = packed_color;
        *((uint32_t*)(adr + 32)) = packed_color;
        *((uint32_t*)(adr + 36)) = packed_color;
        *((uint32_t*)(adr + 40)) = packed_color;
        *((uint32_t*)(adr + 44)) = packed_color;
        *((uint32_t*)(adr + 48)) = packed_color;
        *((uint32_t*)(adr + 52)) = packed_color;
        *((uint32_t*)(adr + 56)) = packed_color;
        *((uint32_t*)(adr + 60)) = packed_color;
        adr += 64;
    }
}

void fillRect(int16_t xoff, int16_t yoff, uint16_t width, uint16_t height, uint8_t color) {
    uint32_t packed_color = packColor(color);

    for(int16_t y = yoff; y < yoff + height; ++y) {
        drawHLine(xoff, y, width, packed_color);
    }
}


void drawCircle(int16_t xoff, int16_t yoff, uint16_t r, uint8_t color) {
    // Horn's algorithm for drawing circles
    int16_t d = -r;
    int16_t x = r;
    int16_t y = 0;
        
    while(y <= x) {
        int16_t xoff_p_x = xoff + x;
        int16_t xoff_m_x = xoff - x;
        int16_t xoff_p_y = xoff + y;
        int16_t xoff_m_y = xoff - y;

        int16_t yoff_p_y = yoff + y;
        int16_t yoff_m_y = yoff - y;
        int16_t yoff_p_x = yoff + x;
        int16_t yoff_m_x = yoff - x;

        drawPixel(xoff_p_x, yoff_p_y, color);
        drawPixel(xoff_m_x, yoff_p_y, color);

        drawPixel(xoff_p_x, yoff_m_y, color);
        drawPixel(xoff_m_x, yoff_m_y, color);
            
        drawPixel(xoff_m_y, yoff_m_x, color);
        drawPixel(xoff_p_y, yoff_m_x, color);

        drawPixel(xoff_m_y, yoff_p_x, color);
        drawPixel(xoff_p_y, yoff_p_x, color);

        d = d + (2*y) + 1;
        y = y + 1;
        if(d > 0) {
            x = x - 1;
            d = d - (2*x);
        }
    }
}


void fillCircle(int16_t xoff, int16_t yoff, uint16_t r, uint8_t color) {
    // Horn's algorithm
    int16_t d = -r;
    int16_t x = r;
    int16_t y = 0;

    uint32_t packed_color = packColor(color);

    while(y <= x) {
        drawHLine(xoff - x, yoff + y, 2*x + 1, packed_color);
        drawHLine(xoff - x, yoff - y, 2*x + 1, packed_color);
        drawHLine(xoff - y, yoff - x, 2*y + 1, packed_color);
        drawHLine(xoff - y, yoff + x, 2*y + 1, packed_color);

        d = d + (2*y) + 1;
        y = y + 1;
        if(d > 0) {
            x = x - 1;
            d = d - (2*x);
        }
    }
}

void fillTriangle(int16_t x0, int16_t y0, int16_t x1, int16_t y1, int16_t x2, int16_t y2, uint8_t color) {

     if(y0 == y1 && y1 == y2) {
        // squished triangle
        return;
    }

    // rotate triangle vertices until y0 is unequal to y1 and y2 AND above or below
    while(((y0 < y1) && (y0 >= y2)) || ((y0 >= y1) && (y0 < y2)) || (y0 == y1) || (y0 == y2)) {
        int16_t tmp = x0;
        x0 = x1;
        x1 = x2;
        x2 = tmp;

        tmp = y0;
        y0 = y1;
        y1 = y2;
        y2 = tmp;
    }

    // y1 needs to be between y0 and y2
    if(((y0 < y2 && y1 > y2)) || ((y0 > y2) && (y1 < y2))) {
        int16_t tmp = x1;
        x1 = x2;
        x2 = tmp;
        tmp = y1;
        y1 = y2;
        y2 = tmp;
    }

    int16_t dx1, sx1;
    if(x0 < x1) {
        dx1 = x1 - x0;
        sx1 = 1;
    } else {
        dx1 = x0 - x1;
        sx1 = -1;
    }

    int16_t dy1;
    if(y0 < y1) {
        dy1 = y0 - y1;
    } else {
        dy1 = y1 - y0;
    }

    int16_t dx2, sx2;
    if(x0 < x2) {
        dx2 = x2 - x0;
        sx2 = 1;
    } else {
        dx2 = x0 - x2;
        sx2 = -1;
    }

    int16_t dy2, sy;
    if(y0 < y2) {
        dy2 = y0 - y2;
        sy = 1;
    } else {
        dy2 = y2 - y0;
        sy = -1;
    }

    int16_t line1_x = x0;
    int16_t line2_x = x0;
    int16_t line1_err = dx1 + dy1;
    int16_t line2_err = dx2 + dy2;

    int16_t current_y = y0;

    int16_t minx, maxx;

    uint32_t packed_color = packColor(color);

    while(current_y != y2) {
        maxx = line1_x > line2_x ? line1_x : line2_x;
        minx = line1_x < line2_x ? line1_x : line2_x;

        // follow first line
        while(1) {
            int16_t e2 = line1_err + line1_err;
            if(e2 >= dy1) {
                line1_err += dy1;
                line1_x += sx1;
            }                

            if(e2 <= dx1) {
                // leaving current line
                line1_err += dx1;
                break;
            }
        }
        // follow second line
        while(1) {
            int16_t e2 = line2_err + line2_err;
            if(e2 >= dy2) {
                line2_err += dy2;
                line2_x += sx2;
            }

            if(e2 <= dx2) {
                // leaving current line
                line2_err += dx2;
                break;
            }
        }
        
        if(line1_x > maxx) maxx = line1_x;
        if(line2_x > maxx) maxx = line2_x;
        if(line1_x < minx) minx = line1_x;
        if(line2_x < minx) minx = line2_x;

        drawHLine(minx, current_y, (maxx - minx) + 1, packed_color);
        current_y += sy;

        if(current_y == y1) {
            // reaching y1, redirecting line 1 to x2/y2
            line1_x = x1;

            if(x1 < x2) {
                dx1 = x2 - x1;
                sx1 = 1;
            } else {
                dx1 = x1 - x2;
                sx1 = -1;
            }

            if(y1 < y2) {
                dy1 = y1 - y2;
            } else {
                dy1 = y2 - y1;
            }
            line1_err = dx1 + dy1;
        }        
    }
}


int main() {

    set_prng_seed(0x1337);
    uint8_t color = get_prng_value() & 0xFF;
    int start, end;

    uint32_t base = 128 * 1024;
    setVGABase(base);

    uint8_t count = 0;

	while(1) {
        // use double-buffering
        setVGABase(count & 0x01 ? 128*1024 : 256*1024);

        set_leds_value(0);
        setClip(0, screenwidth - 1, 0, screenheight - 1);

        ///////////////

        start = get_milli_time();
        fillScreen(color);
        color = get_prng_value() & 0xFF;
        end = get_milli_time();
        printf("time for screen fill: %d\n\r", end - start);

        ///////////////

        setClip(160, screenwidth-1, 120, screenheight-1);

        start = get_milli_time();
        fillCircle(160, 120, 64, color);
        color = get_prng_value() & 0xFF;
        end = get_milli_time();
        printf("time for circle fill: %d\n\r", end - start);

        setClip(0, screenwidth-1, 0, screenheight-1);

        ///////////////
       
        setClip(0, 160, 0, 120);

        start = get_milli_time();
        drawCircle(160, 120, 80, color);
        color = get_prng_value() & 0xFF;
        end = get_milli_time();
        printf("time for circle draw: %d\n\r", end - start);

        setClip(0, screenwidth-1, 0, screenheight-1);

        ///////////////

        start = get_milli_time();
        fillTriangle(20,60, 50,40, 40,80, color);
        fillTriangle(250,150, 280,130, 290,180, color);
        fillTriangle(20,210, 35,170, 60,180, color);

        color = get_prng_value() & 0xFF;
        end = get_milli_time();
        printf("time for triangle fill: %d\n\r", end - start);

        ///////////////

        color = get_prng_value() & 0xFF;
        fillRect(0, 0, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(0, 1, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(0, 2, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(0, 3, 20, 1, color);


        color = get_prng_value() & 0xFF;
        fillRect(300, 0, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(300, 1, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(300, 2, 20, 1, color);
        color = get_prng_value() & 0xFF;
        fillRect(300, 3, 20, 1, color);

        // double-buffering: show picture
        switchVGABase();
        
        start = get_milli_time();
        while(get_milli_time() - start < 5000) {
        }

        count++;

	}

	return 0;
}

