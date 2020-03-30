#ifndef TINYLIB
#define TINYLIB

#include <stddef.h>

#include "../bios_calls/bios_calls.h"

void printf_c(char c);
void printf_s(char* s);
void printf_d(int i);
void printf(const char* format, ...);

char *read_string(char *buf, int n, char echo);

int parse_int(char *str);
long long parse_long(char *str);


void *memcpy(void *str1, const void *str2, size_t n);

size_t strlen(const char *s);
char *strncat(char *dest, const char *src, size_t n);
char *strcpy(char *dest, const char *src);
int strcmp(const char *str1, const char *str2);

void softterm_init(char *textbase);


#endif
