#include "libtinyc.h"
#include "../../asm/devices.h"
#include <stdarg.h>
#include <stdint.h>

#include "../bios_calls/bios_calls.c"

#define UART_DATA *((volatile char*)DEV_UART_DATA)
#define UART_RREADY *((volatile char*)DEV_UART_RX_READY)
#define UART_WREADY *((volatile char*)DEV_UART_TX_READY)


void printf_c(char c)
{
#ifdef NOBIOS
    // wait until serial interface is ready to transmit
    while (!UART_WREADY) {
    };
    // write character
    UART_DATA = c;
#else
    bios_stream_write(DEVICE_STDOUT, &c, 1);
#endif
}

void printf_s(char* s)
{
    while (*s)
        printf_c(*(s++));
}

char _read_character_uart()
{
#ifdef NOBIOS
    while (!UART_RREADY) {
    }
    return UART_DATA;
#else
    char c;
    bios_stream_read(DEVICE_UART, &c, 1);
    return c;
#endif
}

char* read_string(char* buf, int n, char echo)
{
    int idx = 0;
    int maxlen = n - 1;
    while (idx < maxlen) {
        char c = _read_character_uart();
        if (c == '\r' || c == '\n') {
            break;
        }

        if (c != ((char)0x7F)) {
            buf[idx++] = c;
            if (echo)
                printf_c(c);
        } else {
            // handle backspace
            if (idx > 0) {
                idx--;
                printf("\b \b");
            }
        }
    }
    buf[idx] = (char)0;

    return buf;
}

int parse_int(char* str)
{
    return (int)parse_long(str);
}

long long parse_long(char* str)
{
    long long result = 0;
    char negative = 0;
    while (1) {
        char c = *str;
        if (!c)
            break;
        if (c == '-') {
            negative = 1;
        }

        if (c >= '0' && c <= '9') {
            result *= 10;
            result += (c - '0');
        }

        str++;
    }

    if (negative) {
        result *= -1;
    }

    return result;
}

// implementation lifted from Clifford Wolf's PicoRV32 stdlib.c
void printf_d(int i)
{
    char buf[16];
    char* p = buf;

    // output sign for negative input
    if (i < 0) {
        printf_c('-');
        i *= -1;
    }

    while (i > 0 || p == buf) {
        // put lowest decimal digit into buffer
        *(p++) = (char)('0' + (i % 10));
        // shift right by one decimal digit
        i /= 10;
    }

    // output buffer, highest digits first
    while (p != buf) {
        printf_c(*(--p));
    }
}

// implementation lifted from Clifford Wolf's PicoRV32 stdlib.c
void printf(const char* format, ...)
{
    int i;
    va_list ap;

    va_start(ap, format);

    for (i = 0; format[i]; i++) {
        if (format[i] == '%') {
            while (format[++i]) {
                if (format[i] == 'c') {
                    printf_c(va_arg(ap, int));
                    break;
                }
                if (format[i] == 's') {
                    printf_s(va_arg(ap, char*));
                    break;
                }
                if (format[i] == 'd') {
                    printf_d(va_arg(ap, int));
                    break;
                }
            }
        } else {
            printf_c(format[i]);
        }
    }

    va_end(ap);
}

void* memcpy(void* str1, const void* str2, size_t n)
{
    char* a = str1;
    const char* b = str2;
    while (n--) {
        *(a++) = *(b++);
    }
    return str1;
}

size_t strlen(const char* s)
{
    size_t len = 0;
    while (*s++) {
        len++;
    }
    return len;
}

char* strncat(char* dest, const char* src, size_t n)
{
    size_t dest_len = strlen(dest);
    size_t i;

    for (i = 0; i < n && src[i] != '\0'; i++) {
        dest[dest_len + i] = src[i];
    }
    dest[dest_len + i] = '\0';

    return dest;
}

char* strcpy(char* dest, const char* src)
{
    char* dst = dest;
    while (1) {
        char c = *src;
        *dst = c;
        if (c == 0) {
            break;
        }
        src++;
        dst++;
    }

    return dest;
}

// implementation lifted from Clifford Wolf's PicoRV32 stdlib.c
int strcmp(const char* s1, const char* s2)
{
    while ((((uint32_t)s1 | (uint32_t)s2) & 3) != 0) {
        char c1 = *(s1++);
        char c2 = *(s2++);

        if (c1 != c2)
            return c1 < c2 ? -1 : +1;
        else if (!c1)
            return 0;
    }

    while (1) {
        uint32_t v1 = *(uint32_t*)s1;
        uint32_t v2 = *(uint32_t*)s2;

        if (__builtin_expect(v1 != v2, 0)) {
            char c1, c2;

            c1 = v1 & 0xff, c2 = v2 & 0xff;
            if (c1 != c2)
                return c1 < c2 ? -1 : +1;
            if (!c1)
                return 0;
            v1 = v1 >> 8, v2 = v2 >> 8;

            c1 = v1 & 0xff, c2 = v2 & 0xff;
            if (c1 != c2)
                return c1 < c2 ? -1 : +1;
            if (!c1)
                return 0;
            v1 = v1 >> 8, v2 = v2 >> 8;

            c1 = v1 & 0xff, c2 = v2 & 0xff;
            if (c1 != c2)
                return c1 < c2 ? -1 : +1;
            if (!c1)
                return 0;
            v1 = v1 >> 8, v2 = v2 >> 8;

            c1 = v1 & 0xff, c2 = v2 & 0xff;
            if (c1 != c2)
                return c1 < c2 ? -1 : +1;
            return 0;
        }

        if (__builtin_expect((((v1)-0x01010101UL) & ~(v1)&0x80808080UL), 0))
            return 0;

        s1 += 4;
        s2 += 4;
    }
}
