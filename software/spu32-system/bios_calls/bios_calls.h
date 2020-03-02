#ifndef _BIOS_CALLS_H
#define _BIOS_CALLS_H

#include "../bios/bios_shared.h"

result_t block_init(device_t device, struct block_device_info_t* info);
result_t block_read(device_t device, uint32_t block, void* buf, uint32_t len);
result_t block_write(device_t device, uint32_t block, void* buf, uint32_t len);

result_t stream_available(device_t device, uint32_t* available);
result_t stream_read(device_t device, void* buf, uint32_t len);
result_t stream_write(device_t device, void* buf, uint32_t len);

result_t fs_init(device_t device);
result_t fs_open(filehandle_t* filehandle, char* path, filemode_t mode);
result_t fs_close(filehandle_t fh);
result_t fs_read(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* readbytes);
result_t fs_write(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* writtenbytes);
result_t fs_unlink(char* path);
result_t fs_findfirst(char* path, char* pattern, struct file_info_t* fileinfo);
result_t fs_findnext(struct file_info_t* fileinfo);
result_t fs_getcwd(char* buf, uint32_t len);
result_t fs_chdir(char* path);
result_t fs_free(uint64_t* free);
result_t fs_seek(filehandle_t fh, uint32_t position);
result_t fs_mkdir(char* path);
result_t fs_rename(char* oldname, char* newname);
result_t fs_size(filehandle_t fh, uint32_t* size);
result_t fs_tell(filehandle_t fh, uint32_t* position);
result_t fs_stat(char* path, struct file_info_t* fileinfo);


#endif