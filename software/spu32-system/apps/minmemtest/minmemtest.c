#include <stdint.h>
#include "../../bios/devices.h"

/**
 * This little memtest routine is kept minimal to run bare-metal without BIOS invocations and such
 **/


inline uint32_t get_prng_value() {
	volatile uint32_t* dev = (uint32_t*)DEV_PRNG;
	return *dev;
}

inline void set_prng_seed(uint32_t seed) {
	volatile uint32_t* dev = (uint32_t*)DEV_PRNG;
	*dev = seed;
}

inline void set_leds(uint8_t value) {
	volatile uint8_t* dev = (uint8_t*)DEV_LED;
	*dev = value;
}

inline uint32_t get_time() {
	volatile uint32_t* dev = (uint32_t*)DEV_TIMER;
	return *dev;
}


int main()
{

	// when testing the SRAM controller, SRAM will begin at 0x01000000
	uint32_t offset = 0x01000000;

	// without SRAM, theres 8 KB of BRAM, looping over and over
	uint32_t memsize = 8 * 1024;

	while (1)
	{
		const uint32_t base = offset + 256; // don't start at zero to avoid overwriting this program
		const uint32_t end = offset + memsize;

		volatile uint8_t *bytePtr;

		uint32_t pass = 0;

		while(1) {

			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(bytePtr = (volatile uint8_t*)base;(uint32_t)bytePtr < end; bytePtr++) {
				uint8_t prn = (uint8_t)(get_prng_value() & 0xFF);
				*bytePtr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(bytePtr = (volatile uint8_t*)base;(uint32_t)bytePtr < end; bytePtr++) {
				uint8_t prn = (uint8_t)(get_prng_value() & 0xFF);
				uint8_t val = *bytePtr;
				if(prn != val) {
					while(1){
						uint32_t now = get_time();

						// show expected value for a while
						set_leds(prn);
						while(get_time() < now + 800){};
						

						// show returned value for a while
						set_leds(val);
						while(get_time() < now + 1600){};
						
						// clear LEDS, long pause
						set_leds(0);
						while(get_time() < now + 3000){};
					};
				}
			}

			set_leds(pass & 0xFF);

			pass++;
		}
	}


	return 0;
}
