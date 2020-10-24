#ifndef CMDS_SHARED_H
#define CMDS_SHARED_H

void clear_buf(char* buf, int len);
int arg1_func(int argn, char** argv, int (*fun)(char*));
int arg2_func(int argn, char** argv, int (*fun)(char*, char*));

#endif