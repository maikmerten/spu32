#include <libtinyc.h>
#include <libspu32.h>
#include <stdint.h>

int main() {

    volatile uint8_t* IR_ADDR = (volatile uint8_t*) 0xFFFFFC00;
    volatile uint8_t* IR_ADDR_INV = (volatile uint8_t*) 0xFFFFFC01;
    volatile uint8_t* IR_CMD = (volatile uint8_t*) 0xFFFFFC02;
    volatile uint8_t* IR_CMD_INV = (volatile uint8_t*) 0xFFFFFC03;


	while(1) {

        uint8_t addr = *IR_ADDR;
        uint8_t addr_inv = *IR_ADDR_INV;
        uint8_t cmd = *IR_CMD;
        uint8_t cmd_inv = *IR_CMD_INV;

        // check if valid data was received
        if(cmd ^ cmd_inv == 0xFF) {
            printf("addr: %d   addr_inv: %d   cmd: %d   cmd_inv: %d\n\r", addr, addr_inv, cmd, cmd_inv);

            // acknowledge, prepare decoder for new data
            *IR_CMD = 0;
        }

	}

	return 0;
}

