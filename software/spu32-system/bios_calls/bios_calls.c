#include "bios_calls.h"

// Push memory address of request structure into register t0. The interrupt service
// routine will access requests using this address. Then use the ecall instruction to
// defer execution to the interrupt service routine.
inline void call_environment(void* request_addr) {
    asm("or t0, zero, %[value]" : : [value] "r" (request_addr) );
    asm("ecall");   
}

result_t bios_block_init(device_t device, struct block_device_info_t* info) {
    struct request_init_block_device_t req;

    req.command = CMD_INIT_BLOCK_DEVICE;
    req.device = device;
    call_environment(&req);

    info->blocks = req.blocks;
    info->block_size = req.block_size;

    return req.result;
}

// set up structure for block read request and invoke BIOS
result_t bios_block_read(device_t device, uint32_t block, void* buf, uint32_t len) {
    struct request_readwrite_block_t req;

    req.command = CMD_READ_BLOCK;
    req.device = device;
    req.block = block;
    req.buf = buf;
    req.len = len;

    call_environment(&req);
    return req.result;
}

// set up structure for block write request and invoke BIOS
result_t bios_block_write(device_t device, uint32_t block, void* buf, uint32_t len) {
    struct request_readwrite_block_t req;

    req.command = CMD_WRITE_BLOCK;
    req.device = device;
    req.block = block;
    req.buf = buf;
    req.len = len;

    call_environment(&req);
    return req.result;
}


// set up structure to request available bytes from stream
result_t bios_stream_available(device_t device, uint32_t* available) {
    struct request_available_stream_t req;

    req.command = CMD_AVAILABLE_STREAM;
    req.device = device;
    call_environment(&req);
    *available = (req.result == RESULT_OK) ? req.available : 0;
    return req.result;
}

// set up structure for stream read request and invoke BIOS
result_t bios_stream_read(device_t device, void* buf, uint32_t len) {
    struct request_readwrite_stream_t req;

    req.command = CMD_READ_STREAM;
    req.device = device;
    req.buf = buf;
    req.len = len;

    call_environment(&req);
    return req.result;
}

// set up structure for stream write request and invoke BIOS
result_t bios_stream_write(device_t device, void* buf, uint32_t len) {
    struct request_readwrite_stream_t req;

    req.command = CMD_WRITE_STREAM;
    req.device = device;
    req.buf = buf;
    req.len = len;

    call_environment(&req);
    return req.result;
}

// set up structure for file system init request and invoke BIOS
result_t bios_fs_init(device_t device) {
    struct request_fs_init_t req;

    req.command = CMD_FS_INIT;
    req.device = device;

    call_environment(&req);
    return req.result;
}

// set up request to open a file
result_t bios_fs_open(filehandle_t* filehandle, char* path, filemode_t mode) {
    struct request_fs_open_t req;

    req.command = CMD_FS_OPENFILE;
    req.filehandle = filehandle;
    req.path = path;
    req.mode = mode;

    call_environment(&req);
    return req.result;
}

// set up request to close a file
result_t bios_fs_close(filehandle_t fh) {
    struct request_fs_close_t req;

    req.command = CMD_FS_CLOSEFILE;
    req.fh = fh;

    call_environment(&req);
    return req.result;
}


// set up request for file reads
result_t bios_fs_read(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* readbytes) {
    struct request_fs_read_t req;
    
    req.command = CMD_FS_READFILE;
    req.fh = fh;
    req.buf = buf;
    req.nbytes = nbytes;
    req.readbytes = readbytes;

    call_environment(&req);
    return req.result;
}

// set up request for file writes
result_t bios_fs_write(filehandle_t fh, void* buf, uint32_t nbytes, uint32_t* writtenbytes) {
    struct request_fs_write_t req;
    
    req.command = CMD_FS_WRITEFILE;
    req.fh = fh;
    req.buf = buf;
    req.nbytes = nbytes;
    req.writtenbytes = writtenbytes;

    call_environment(&req);
    return req.result;
}

// set up request to unlink files or directories
result_t bios_fs_unlink(char* path) {
    struct request_fs_unlink_t req;

    req.command = CMD_FS_UNLINK;
    req.path = path;

    call_environment(&req);
    return req.result;
}

// set up request to start directory listing
result_t bios_fs_findfirst(char* path, char* pattern, struct file_info_t* fileinfo) {
    struct request_fs_findfirst_t req;

    req.command = CMD_FS_FINDFIRST;
    req.path = path;
    req.pattern = pattern;
    req.fileinfo = fileinfo;

    call_environment(&req);
    return req.result;    
}

// set up request to continue directory listing
result_t bios_fs_findnext(struct file_info_t* fileinfo) {
    struct request_fs_findnext_t req;

    req.command = CMD_FS_FINDNEXT;
    req.fileinfo = fileinfo;

    call_environment(&req);
    return req.result;    
}

// set up request to get current workdir
result_t bios_fs_getcwd(char* buf, uint32_t len) {
    struct request_fs_getcwd_t req;

    req.command = CMD_FS_GETCWD;
    req.buf = buf;
    req.len = len;

    call_environment(&req);
    return req.result;    
}

// set up request to change current workdir
result_t bios_fs_chdir(char* path) {
    struct request_fs_chdir_t req;

    req.command = CMD_FS_CHDIR;
    req.path = path;

    call_environment(&req);
    return req.result;
}

// set up request to determine number of free bytes on FS
result_t bios_fs_free(uint64_t* free) {
    struct request_fs_free_t req;

    req.command = CMD_FS_FREE;
    req.free = free;

    call_environment(&req);
    return req.result;
}

// set up request for file seeks
result_t bios_fs_seek(filehandle_t fh, uint32_t position) {
    struct request_fs_seek_t req;

    req.command = CMD_FS_SEEK;
    req.fh = fh;
    req.position = position;

    call_environment(&req);
    return req.result;
}

// set up requests for making directories
result_t bios_fs_mkdir(char* path) {
    struct request_fs_mkdir_t req;

    req.command = CMD_FS_MKDIR;
    req.path = path;

    call_environment(&req);
    return req.result;

}

// set up requests for renaming objects on the FS
result_t bios_fs_rename(char* oldname, char* newname) {
    struct request_fs_rename_t req;

    req.command = CMD_FS_RENAME;
    req.oldname = oldname;
    req.newname = newname;

    call_environment(&req);
    return req.result;
}

// set up requests to determine file size
result_t bios_fs_size(filehandle_t fh, uint32_t* size) {
    struct request_fs_size_t req;

    req.command = CMD_FS_SIZE;
    req.fh = fh;
    req.size = size;

    call_environment(&req);
    return req.result;
}

// set up request to determine position in file
result_t bios_fs_tell(filehandle_t fh, uint32_t* position) {
    struct request_fs_tell_t req;

    req.command = CMD_FS_TELL;
    req.fh = fh;
    req.position = position;

    call_environment(&req);
    return req.result;
}


// set up request to retrieve file information
result_t bios_fs_stat(char* path, struct file_info_t* fileinfo) {
    struct request_fs_stat_t req;

    req.command = CMD_FS_STAT;
    req.path = path;
    req.fileinfo = fileinfo;

    call_environment(&req);
    return req.result;
}

// set up request to set video mode
result_t bios_video_set_mode(videomode_t mode, void* videobase, void* fontbase) {
    struct request_video_set_mode_t req;

    req.command = CMD_VIDEO_SETMODE;
    req.mode = mode;
    req.videobase = videobase;
    req.fontbase = fontbase;

    call_environment(&req);
    return req.result;
}


// set up request to set video colour palette
result_t bios_video_set_palette(uint8_t* palette) {
    struct request_video_set_palette_t req;

    req.command = CMD_VIDEO_SETPALETTE;
    req.palette = palette;

    call_environment(&req);
    return req.result;
}
