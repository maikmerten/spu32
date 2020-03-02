#ifndef BIOS_FATFS_H
#define BIOS_FATFS_H

#include "bios_shared.h"

result_t bios_fatfs_init();
result_t bios_fatfs_open(filehandle_t* filehandle, char* path, filemode_t mode);
result_t bios_fatfs_close(filehandle_t fh);
result_t bios_fatfs_read(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* readbytes);
result_t bios_fatfs_write(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* writtenbytes);
result_t bios_fatfs_unlink(char* path);
result_t bios_fatfs_findfirst(char* path, char* pattern, struct file_info_t* finfo);
result_t bios_fatfs_findnext(struct file_info_t* finfo);
result_t bios_fatfs_getcwd(char* buf, uint32_t len);
result_t bios_fatfs_chdir(char* path);
result_t bios_fatfs_free(uint64_t* free);
result_t bios_fatfs_seek(filehandle_t fh, uint32_t position);
result_t bios_fatfs_mkdir(char* path);
result_t bios_fatfs_rename(char* oldname, char* newname);
result_t bios_fatfs_size(filehandle_t fh, uint32_t* size);
result_t bios_fatfs_tell(filehandle_t, uint32_t* position);
result_t bios_fatfs_stat(char* path, struct file_info_t* finfo);

#endif