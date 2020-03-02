#include <stdint.h>
#include "bios_shared.h"
#include "bios_uart.h"


void bios_uart_read(struct request_readwrite_stream_t* request) {
    uint8_t* buffer = request->buf;
    for(uint32_t i = 0; i < request->len; ++i) {
        while(!UART_RREADY) {}
        buffer[i] = UART_DATA;
    }
}

void bios_uart_write(struct request_readwrite_stream_t* request) {
    uint8_t* buffer = request->buf;
    for(uint32_t i = 0; i < request->len; ++i) {
        while(!UART_WREADY) {}
        UART_DATA = buffer[i];
    }
}
