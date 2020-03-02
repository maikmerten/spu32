#ifndef BIOS_SDCARD_H
#define BIOS_SDCARD_H

#include <stdint.h>
#include "bios_shared.h"

result_t bios_sd_read_block(uint32_t blocknr, uint8_t* buf);
result_t bios_sd_write_block(uint32_t blocknr, uint8_t* buf);
result_t bios_sd_init(struct request_init_block_device_t* request);


#endif