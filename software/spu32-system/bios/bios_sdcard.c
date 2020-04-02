#include <stdint.h>
#include "bios_shared.h"
#include "bios_spi.h"

#define LED *((volatile uint8_t*)DEV_LED)

void bios_sd_select() {
    bios_spi_transmit(0xFF);
    bios_spi_select(2);
    bios_spi_transmit(0xFF);
}

void bios_sd_deselect() {
    bios_spi_transmit(0xFF);
    bios_spi_select(0);
    bios_spi_transmit(0xFF);
}

// in case of error, deselect device
result_t bios_sd_error() {
    bios_sd_deselect();
    return RESULT_ERR;
}


static inline uint8_t bios_sd_get_crc(uint8_t message[], uint32_t length) {
    const uint8_t crcPoly = 0x89;
    uint8_t crc = 0;

    for (uint32_t i = 0; i < length; ++i) {
        for(uint32_t j = 0; j < 8; ++j) {
            crc <<= 1;
            if(j == 0) {
                crc ^= message[i];
            }

            if(crc & 0x80) {
                crc ^= crcPoly;
            }
        }
    }
    return crc;
}

void bios_sd_assemble_cmd(uint8_t cmd, uint32_t params, uint8_t* buf) {
    buf[0] = cmd | 0x40;
    buf[1] = (params >> 24) & 0xFF;
    buf[2] = (params >> 16) & 0xFF;
    buf[3] = (params >> 8) & 0xFF;
    buf[4] = params & 0xFF;
    buf[5] = (bios_sd_get_crc(buf, 5) << 1) | 1;
}


void bios_sd_send_cmd(uint8_t cmd, uint32_t params, uint8_t* cmdbuf) {
    bios_sd_assemble_cmd(cmd, params, cmdbuf);
    
    bios_sd_select();

    for(uint32_t i = 0; i < 6; ++i) {
        bios_spi_transmit(cmdbuf[i]);
    }
    
    uint8_t count = 0;
    do {
        cmdbuf[0] = bios_spi_transmit(0xFF);
        count++;
    } while(cmdbuf[0] & 0x80 && count < 100);

    cmdbuf[1] = bios_spi_transmit(0xFF);
    cmdbuf[2] = bios_spi_transmit(0xFF);
    cmdbuf[3] = bios_spi_transmit(0xFF);
    cmdbuf[4] = bios_spi_transmit(0xFF);

    bios_sd_deselect();
}

result_t bios_sd_read_block(uint32_t blocknr, uint8_t* buf) {
    uint8_t cmd[6];
    bios_sd_assemble_cmd(17, blocknr, cmd);
    uint8_t response;

    bios_sd_select();
    for(uint32_t i = 0; i < 6; ++i) {
        bios_spi_transmit(cmd[i]);
    }

    uint8_t count = 0;
    do {
        response = bios_spi_transmit(0xFF);
        count++;
    } while(response & 0x80 && count < 100);


    if(response != 0) {
        return bios_sd_error();
    }

    // wait for 0xFE data start token
    uint32_t retries = 0;
    do {
        response = bios_spi_transmit(0xFF);
        if(retries++ > 10000) {
            return bios_sd_error();
        }
    } while(response != 0xFE);

    // read 512 bytes of data
    for(uint32_t i = 0; i < 512; ++i) {
        buf[i] = bios_spi_transmit(0xFF);
    }

    bios_sd_deselect();
    return RESULT_OK;
}

result_t bios_sd_write_block(uint32_t blocknr, uint8_t* buf) {
    uint8_t cmd[6];
    bios_sd_assemble_cmd(24, blocknr, cmd);
    uint8_t response;

    bios_sd_select();
    for(uint32_t i = 0; i < 6; ++i) {
        bios_spi_transmit(cmd[i]);
    }

    uint8_t count = 0;
    do {
        response = bios_spi_transmit(0xFF);
        count++;
    } while(response & 0x80 && count < 100);

    if(response != 0) {
        return bios_sd_error();
    }

    // data start token
    bios_spi_transmit(0xFE);
    // transmit block data
    for(uint32_t i = 0; i < 512; ++i) {
        bios_spi_transmit(buf[i]);
    }

    // wait for data response xxx0xxx1
    do {
        response = bios_spi_transmit(0xFF);
    } while((response & 0x11) != 0x01);

    response &= 0x0E;

    if(response == (0b010 << 1)) {
        // data accepted
    } else if(response == (0b101 << 1)) {
        // data rejected, CRC error
        return bios_sd_error();
    } else if(response == (0b110 << 1)) {
        // data rejected, write error
        return bios_sd_error();
    }

    // wait until card is not busy anymore
    do {
        response = bios_spi_transmit(0xFF);
    } while(response == 0);

    bios_sd_deselect();
    return RESULT_OK;
}


result_t bios_sd_init(struct request_init_block_device_t* request) {
    uint8_t buf[24];

    // ensure that SPI device is deselected
    bios_sd_deselect();

    // send dummy clock pulses for device startup
    bios_sd_select();
    for(uint32_t i = 0; i < 200; ++i) {
        bios_spi_transmit(0xFF);
    }
    bios_sd_deselect();

    uint32_t retries = 0;
    while(1) {
        bios_sd_send_cmd(0, 0, buf);
        if(buf[0] != 0x01) {
            if(retries++ > 100) {
                return bios_sd_error();
            }
        } else {
            break;
        }
    }

    // send CMD8
    bios_sd_send_cmd(8, 0x000001AA, buf);
    if(!buf[0] == 0x01) {
        return bios_sd_error();
    }

    // send CMD58
    bios_sd_send_cmd(58, 0, buf);
    if(!buf[0] == 0x01) {
        return bios_sd_error();
    }

    // send ACMD41
    retries = 0;
    do {
        bios_sd_send_cmd(55, 0, buf);
        if(buf[0] != 0x01) {
            return bios_sd_error();
        }

        bios_sd_send_cmd(41, 0x40000000, buf);
        if(buf[0] == 0x00) {
            break;
        }
        retries++;
        if(retries > 1000) {
            return bios_sd_error();
        }
    } while(1);


    bios_sd_send_cmd(58, 0, buf);
    if(buf[0] != 0x00) {
        return bios_sd_error();
    }

    request->block_size = 512;

    // read card-specific data (CSD) with CMD9
    bios_sd_assemble_cmd(9, 0, buf);
    bios_sd_select();
    for(int i = 0; i < 6; ++i) {
        bios_spi_transmit(buf[i]);
    }
    
    uint8_t response;
    retries = 0;
    do {
        response = bios_spi_transmit(0xFF);
        if(retries++ > 1000) {
            return bios_sd_error();
        }
    } while(response != 0xFE); // wait for data start token

    for(int i = 0; i < 24; ++i) {
        buf[i] = bios_spi_transmit(0xFF);
    }

    bios_sd_deselect();
    
    if(buf[0] != 0x40) {
        // expect CSD version 2.0
        return RESULT_ERR;
    }

    uint32_t csize = (((uint32_t)buf[7]) << 16) | ((uint32_t)(buf[8]) << 8) | ((uint32_t)buf[9]);
    request->blocks = (csize + 1) << 10;

    return RESULT_OK;
}
