#ifndef BIOS_SPI_H
#define BIOS_SPI_H

#include <stdint.h>
#include "devices.h"

uint8_t bios_spi_transmit(uint8_t txdata);

static inline void bios_spi_select(uint8_t spi_device) {
    *((volatile uint8_t*)DEV_SPI_SELECT) = spi_device;
}

#endif
