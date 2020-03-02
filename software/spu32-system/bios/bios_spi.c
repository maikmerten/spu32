#include <stdint.h>
#include "devices.h"


uint8_t bios_spi_transmit(uint8_t txdata) {
	// wait till SPI is ready
	while(!*((volatile uint8_t*)DEV_SPI_READY)){};

	// send data
	*((volatile uint8_t*)DEV_SPI_DATA) = txdata;

	// wait till transmission has finished
	while(!*((volatile uint8_t*)DEV_SPI_READY)){};

	return *((volatile uint8_t*)DEV_SPI_DATA);
}

