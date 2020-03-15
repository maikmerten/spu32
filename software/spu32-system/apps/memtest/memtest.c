#include <libtinyc.h>
#include <stdint.h>
#include "../../bios/devices.h"

inline int get_prng_value() {
	volatile int* dev = (int*)DEV_PRNG;
	return *dev;
}

inline void set_prng_seed(int seed) {
	volatile int* dev = (int*)DEV_PRNG;
	*dev = seed;
}

// dial down on the optimizations to prevent GCC from optimizing this to nothing
#pragma GCC push_options
#pragma GCC optimize ("Og")
int detectMemsize() {
	int memsize = 4096;
	while(1) {
		volatile unsigned char *zeroPtr = (volatile unsigned char*) 0;
		volatile unsigned char *endPtr = (volatile unsigned char*) (memsize);
		// read byte from memory location 0
		unsigned char c1 = *zeroPtr;
		// write modified value beyond last address of suspected memory size
		*endPtr = c1 ^ 0xFF;
		// read back value from memory location 0
		unsigned char c2 = *zeroPtr;
		// if value at location 0 changed, then we found the proper memory size
		if(c1 != c2) {
			break;
		}
		// otherwise increase suspected memory size and repeat
		memsize +=1024;
	}

	return memsize;
}
#pragma GCC pop_options

#define VGA_BASE *((volatile uint32_t*) DEV_VGA_BASE)
#define VGA_MODE *((volatile uint8_t*) DEV_VGA_MODE)


int main()
{

	int memsize = 512 * 1024;
	printf("Detected memory size: %d bytes\n\r", memsize);

	VGA_BASE = (32 * 1024);
	VGA_MODE = 3;


	while (1)
	{
		const int base = (4 * 1024); // start at 4K, don't overwrite memtest program
		const int end = (memsize - (64 * 1024)); // leave top 64K intact, don't trash environment

		volatile unsigned char *bytePtr;
		volatile unsigned int *intPtr;
		int error = 0;


		bytePtr = (volatile unsigned char*)base;
		for(int i = 0; i < 256; ++i) {
			*bytePtr++ = i;
		}

		bytePtr = (volatile unsigned char*)base;
		for(int i = 0; i < 256; ++i) {
			int read = *bytePtr++;
			printf("%d read as %d\n\r", i, read);
			if(read != i) error++;
		}

		printf("byte read errors: %d\n\r", error);
		if(error) {
			printf("byte read/write failed");
			while(1) {}
		}


		int pass = 0;

		while(1) {
			printf("pass with seed %d\r\n", pass);


			set_prng_seed(pass);
			// write predictable random numbers to memory
			for(intPtr = (volatile unsigned int*)base;(int)intPtr < end; intPtr++) {
				int prn = get_prng_value();
				*intPtr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(intPtr = (volatile unsigned int*)base;(int)intPtr < end; intPtr++) {
				int prn = get_prng_value();
				int val = *intPtr;
				if(prn != val) {
					printf("read %d from address %d, but expected %d\r\n", val, (int)intPtr, prn);
					while(1){};
				}
			}

			pass++;
		}


	}


	return 0;
}
