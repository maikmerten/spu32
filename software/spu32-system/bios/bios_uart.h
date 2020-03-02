#ifndef BIOS_UART_H
#define BIOS_UART_H

#include <stdint.h>
#include "bios_shared.h"
#include "devices.h"

#define UART_DATA   *((volatile uint8_t*)DEV_UART_DATA)
#define UART_RREADY *((volatile uint8_t*)DEV_UART_RX_READY)
#define UART_WREADY *((volatile uint8_t*)DEV_UART_TX_READY)

static inline uint8_t bios_uart_available() {
    return UART_RREADY;
}

void bios_uart_read(struct request_readwrite_stream_t* request);
void bios_uart_write(struct request_readwrite_stream_t* request);


#endif