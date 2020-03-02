/*
First stage of the bootloader, loaded into RAM by the Boot ROM ("stage 0").

 - sets up stack pointer (crt0.s)
 - sets standard VGA color palette
 - loads BIOS from SPI-Flash into RAM
 - loads stage 2 bootloader from SPI-Flash into RAM
 - registers BIOS interrupt service routine (crt0.s)
 - jumps to stage 2 bootloader

Binary size: 4 Kibibyte

*/

#include <stdint.h>
#include "../bios/devices.h"
#include "palette.h"

#define JEDEC_READ 0x03

#define SPI_READY *((volatile uint8_t *)DEV_SPI_READY)
#define SPI_DATA *((volatile uint8_t *)DEV_SPI_DATA)
#define SPI_SELECT *((volatile uint8_t *)DEV_SPI_SELECT)

#define VGA_PALETTE *((volatile uint32_t *)DEV_VGA_PALETTE)

#define STAGE2_FLASH_LOCATION (4 * 1024)
#define STAGE2_SIZE (4 * 1024)
#define STAGE2_RAM_LOCATION (256 * 1024)

#define BIOS_FLASH_LOCATION (8 * 1024)
#define BIOS_SIZE (32 * 1024)
#define BIOS_RAM_LOCATION ((512 - 32) * 1024)

uint8_t transmit_spi(uint8_t txdata)
{
    // wait till SPI is ready
    while (!SPI_READY)
    {
    };

    // send data
    SPI_DATA = txdata;

    // wait till transmission has finished
    while (!SPI_READY)
    {
    };

    return SPI_DATA;
}

void select_spi()
{
    SPI_SELECT = 1;
}

void deselect_spi()
{
    SPI_SELECT = 0;
}

void start_spi_read(uint32_t spiaddr)
{
    transmit_spi(JEDEC_READ);
    transmit_spi((spiaddr >> 16) & 0xFF);
    transmit_spi((spiaddr >> 8) & 0xFF);
    transmit_spi(spiaddr & 0xFF);
}

void fill_buffer_from_spi(volatile uint8_t *buf, uint32_t n, uint32_t spiaddr)
{
    select_spi();
    start_spi_read(spiaddr);

    for (int i = 0; i < n; ++i)
    {
        char c = transmit_spi(0);
        buf[i] = c;
    }

    deselect_spi();
}

void load_stage2()
{
    uint8_t *ram_dest = (uint8_t *)STAGE2_RAM_LOCATION;
    uint32_t size = STAGE2_SIZE;
    uint32_t spi_start = STAGE2_FLASH_LOCATION;
    fill_buffer_from_spi(ram_dest, size, spi_start);
}

void load_bios()
{
    uint8_t *ram_dest = (uint8_t *)BIOS_RAM_LOCATION;
    uint32_t size = BIOS_SIZE;
    uint32_t spi_start = BIOS_FLASH_LOCATION;
    fill_buffer_from_spi(ram_dest, size, spi_start);
}

void load_color_palette()
{
    uint8_t idx = 0;
    while (1)
    {
        uint8_t r = default_palette[idx][0];
        uint8_t g = default_palette[idx][1];
        uint8_t b = default_palette[idx][2];

        VGA_PALETTE = (idx << 24 | (r << 16) | (g << 8) | b);

        if (idx == 0xFF)
        {
            break;
        }
        idx++;
    }
}

int main()
{

    // set standard color palette
    load_color_palette();

    // load BIOS-code from SPI-Flash
    load_bios();

    // load stage 2 boot loader from SPI-Flash
    load_stage2();

    return 0;
}
