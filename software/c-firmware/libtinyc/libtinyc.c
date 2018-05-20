#include <stdarg.h>
#include "libtinyc.h"
#include "../../asm/devices.h"

#define UART_DATA   *((volatile char*)DEV_UART_DATA)
#define UART_RREADY *((volatile char*)DEV_UART_RX_READY)
#define UART_WREADY *((volatile char*)DEV_UART_TX_READY)

void printf_c(char c) {
	// wait until serial interface is ready to transmit
	while(!UART_WREADY){};
	// write character
	UART_DATA = c;
}


void printf_s(char* s) {
	while(*s) printf_c(*(s++));
}

char _read_character_uart() {
	while(!UART_RREADY){}
	return UART_DATA;
}


char *fgets(char *str, int n, void *stream) {
	int idx = 0;
	int maxlen = n - 1;
	while(idx < maxlen) {
		char c = _read_character_uart();
		if(c == '\r' || c == '\n') {
			break;
		}
		printf_c(c);
		str[idx++] = c;
	}
	str[idx] = (char)0;

	return str;
}

// implementation lifted from Clifford Wolf's PicoRV32 stdlib.c
void printf_d(int i) {
	char buf[16];
	char *p = buf;

	// output sign for negative input
	if(i < 0) {
		printf_c('-');
		i *= -1;
	}

	while(i > 0 || p == buf) {
		// put lowest decimal digit into buffer
		*(p++) = (char)('0' + (i % 10));
		// shift right by one decimal digit
		i /= 10;
	}

	// output buffer, highest digits first
	while(p != buf) {
		printf_c(*(--p));
	}
}

// implementation lifted from Clifford Wolf's PicoRV32 stdlib.c
void printf(const char *format, ...) {
	int i;
	va_list ap;

	va_start(ap, format);

	for (i = 0; format[i]; i++) {
		if (format[i] == '%') {
			while (format[++i]) {
				if (format[i] == 'c') {
					printf_c(va_arg(ap,int));
					break;
				}
				if (format[i] == 's') {
					printf_s(va_arg(ap,char*));
					break;
				}
				if (format[i] == 'd') {
					printf_d(va_arg(ap,int));
					break;
				}
			}
		} else {
			printf_c(format[i]);
		}
	}

	va_end(ap);
}


