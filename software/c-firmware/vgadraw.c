#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>

volatile uint32_t* DEV_VGA_BASE = (volatile uint32_t*) 0xFFFF0000;
volatile uint8_t* DEV_VGA_MODE = (volatile uint8_t*) 0xFFFF0008;

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
    *DEV_VGA_MODE = 3;
    *DEV_VGA_BASE = vgabase;
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
    // ported from https://fgiesen.wordpress.com/2013/02/10/optimizing-the-basic-rasterizer/

    uint32_t packed_color = packColor(color);

    int16_t minX = x0 < x1 ? x0 : x1;
    if(x2 < minX) minX = x2;
    int16_t minY = y0 < y1 ? y0 : y1;
    if(y2 < minY) minY = y2;
    int16_t maxX = x0 > x1 ? x0 : x1;
    if(x2 > maxX) maxX = x2;
    int16_t maxY = y0 > y1 ? y0 : y1;
    if(y2 > maxY) maxY = y2;

    // clip to screen
    if(minX < clipxmin) minX = clipxmin;
    if(minY < clipymin) minY = clipymin;
    if(maxX > clipxmax) maxX = clipxmax;
    if(maxY > clipymax) maxY = clipymax;

    // Triangle setup
    int16_t a01 = y0 - y1;
    int16_t b01 = x1 - x0;
    int16_t a12 = y1 - y2;
    int16_t b12 = x2 - x1;
    int16_t a20 = y2 - y0;
    int16_t b20 = x0 - x2;

    // Barycentric coordinates at minX/minY corner
    //let w0_row = orient2d(x1, y1, x2, y2, minX, minY);
    int32_t w0_row = (b12)*(minY-y1) - (y2-y1)*(minX-x1);
    //let w1_row = orient2d(x2, y2, x0, y0, minX, minY);
    int32_t w1_row = (b20)*(minY-y2) - (y0-y2)*(minX-x2);
    //let w2_row = orient2d(x0, y0, x1, y1, minX, minY);
    int32_t w2_row = (b01)*(minY-y0) - (y1-y0)*(minX-x0);

    for(int16_t y = minY; y <= maxY; y++) {
        int32_t w0 = w0_row;
        int32_t w1 = w1_row;
        int32_t w2 = w2_row;

        int16_t startx = -1;
        int16_t rowwidth = 0;

        for(int16_t x = minX; x <= maxX; x++) {
            if(w0 >= 0 && w1 >= 0 && w2 >= 0) {
                // inside triangle
                if(startx < 0) {
                    // entered triangle
                    startx = x;
                }
                rowwidth++;
            } else if(startx >= 0) {
                // exited triangle, break to emit
                break;
            }
            // step to right
            w0 += a12;
            w1 += a20;
            w2 += a01;
        }

        // emit row
        drawHLinePreclipped(startx, y, rowwidth, packed_color);

        // step one row
        w0_row += b12;
        w1_row += b20;
        w2_row += b01;
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


        // double-buffering: show picture
        switchVGABase();
        
        start = get_milli_time();
        while(get_milli_time() - start < 500) {
        }

        count++;

	}

	return 0;
}

