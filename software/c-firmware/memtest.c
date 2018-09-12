#include <libtinyc.h>
#include "../asm/devices.h"

inline int get_prng_value() {
	volatile int* dev = (int*)DEV_PRNG;
	return *dev;
}

inline void set_prng_seed(int seed) {
	volatile int* dev = (int*)DEV_PRNG;
	*dev = seed;
}


int main()
{
	while (1)
	{
		const int base = (4 * 1024); // start at 4K, don't overwrite memtest program
		const int end = (510*1024); // leave top 2K intact, don't trash the stack

		volatile unsigned char *bytePtr;
		volatile unsigned int *intPtr;
		int error = 0;


		bytePtr = (char*)base;
		for(int i = 0; i < 256; ++i) {
			*bytePtr++ = i;
		}

		bytePtr = (char*)base;
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
			for(intPtr = (int*)base;(int)intPtr < end; intPtr += sizeof(int)) {
				int prn = get_prng_value();
				*intPtr = prn;
			}

			// reset predictable number generator
			set_prng_seed(pass);
			// read memory contents and compare
			for(intPtr = (int*)base;(int)intPtr < end; intPtr += sizeof(int)) {
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