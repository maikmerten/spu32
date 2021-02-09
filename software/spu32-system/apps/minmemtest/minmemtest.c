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

	// test a good chunk of memory
	uint32_t memsize = 32 * 1024;

	while (1)
	{
		const uint32_t base = offset + 1024; // don't start at zero to avoid overwriting this program
		const uint32_t end = offset + memsize;

		volatile uint8_t *bytePtr;
		volatile uint16_t *u16Ptr;
		volatile uint32_t *u32Ptr;

		uint32_t pass = 0;

		while(1) {

			///////////////////////////
			// byte tests
			///////////////////////////			

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

			///////////////////////////
			// half-word tests
			///////////////////////////

			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(u16Ptr = (volatile uint16_t*)base;(uint32_t)u16Ptr < end; u16Ptr++) {
				uint16_t prn = (uint16_t)(get_prng_value() & 0xFFFF);
				*u16Ptr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(u16Ptr = (volatile uint16_t*)base;(uint32_t)u16Ptr < end; u16Ptr++) {
				uint16_t prn = (uint16_t)(get_prng_value() & 0xFFFF);
				uint16_t val = *u16Ptr;
				if(prn != val) {
					while(1){
						uint32_t now = get_time();

						
						set_leds(0x1);
						while(get_time() < now + 800){};
						
						// clear LEDS, long pause
						set_leds(0);
						while(get_time() < now + 1600){};
					};
				}
			}

			///////////////////////////
			// unaligned half-word tests
			///////////////////////////

			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(u16Ptr = (volatile uint16_t*)base + 1;(uint32_t)u16Ptr < end; u16Ptr++) {
				uint16_t prn = (uint16_t)(get_prng_value() & 0xFFFF);
				*u16Ptr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(u16Ptr = (volatile uint16_t*)base + 1;(uint32_t)u16Ptr < end; u16Ptr++) {
				uint16_t prn = (uint16_t)(get_prng_value() & 0xFFFF);
				uint16_t val = *u16Ptr;
				if(prn != val) {
					while(1){
						uint32_t now = get_time();

						
						set_leds(0x2);
						while(get_time() < now + 800){};
						
						// clear LEDS, long pause
						set_leds(0);
						while(get_time() < now + 1600){};
					}
				}
			}

			///////////////////////////
			// word tests
			///////////////////////////

			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(u32Ptr = (volatile uint32_t*)base;(uint32_t)u32Ptr < end; u32Ptr++) {
				uint32_t prn = (uint32_t)get_prng_value();
				*u32Ptr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(u32Ptr = (volatile uint32_t*)base;(uint32_t)u32Ptr < end; u32Ptr++) {
				uint32_t prn = (uint32_t)get_prng_value();
				uint32_t val = *u32Ptr;
				if(prn != val) {
					while(1){
						uint32_t now = get_time();

						
						set_leds(0x3);
						while(get_time() < now + 800){};
						
						// clear LEDS, long pause
						set_leds(0);
						while(get_time() < now + 1600){};
					}
				}
			}

			///////////////////////////
			// unaligend word tests
			///////////////////////////

			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(u32Ptr = (volatile uint32_t*)base+1;(uint32_t)u32Ptr < end; u32Ptr++) {
				uint32_t prn = (uint32_t)get_prng_value();
				*u32Ptr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(u32Ptr = (volatile uint32_t*)base+1;(uint32_t)u32Ptr < end; u32Ptr++) {
				uint32_t prn = (uint32_t)get_prng_value();
				uint32_t val = *u32Ptr;
				if(prn != val) {
					while(1){
						uint32_t now = get_time();

						
						set_leds(0x4);
						while(get_time() < now + 800){};
						
						// clear LEDS, long pause
						set_leds(0);
						while(get_time() < now + 1600){};
					}
				}
			}


			set_leds(pass & 0xFF);

			pass++;
		}
	}


	return 0;
}
