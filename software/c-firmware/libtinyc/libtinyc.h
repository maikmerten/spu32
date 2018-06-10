#ifndef TINYLIB
#define TINYLIB

void printf_c(char c);
void printf_s(char* s);
void printf_d(int i);
void printf(const char* format, ...);

char *read_string(char *buf, int n, char echo);

int parse_int(char *str);
long long parse_long(char *str);

int string_length(char *str);

#endif
