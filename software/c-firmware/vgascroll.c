#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>
#include "../asm/devices.h"

#define VGA_BASE *((volatile uint32_t*)DEV_VGA_BASE)
#define VGA_MODE *((volatile uint8_t*)DEV_VGA_MODE)


int main() {

    uint32_t vgabase = (16*1024);
    int32_t maxoff = (960 * 320);
    int32_t off = 0;
    int32_t dir = 320;

    // switch to graphics mode
    VGA_MODE = 1;

	while(1) {

        VGA_BASE = (vgabase + off);
        off += dir;

        if(off == 0 && dir < 0) {
            dir = 320;
        } else if(off >= maxoff && dir > 0) {
            dir = -320;
        }

        if(dir > 0) {
            set_leds_value(0x01);
        } else {
            set_leds_value(0x80);
        }

        for(uint32_t delay = 5000; delay > 0; --delay) {
            uint32_t tmp = VGA_BASE;
        }
	}

	return 0;
}

