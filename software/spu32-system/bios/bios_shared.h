#ifndef BIOS_SHARED_H
#define BIOS_SHARED_H

#include <stdint.h>

/*
 * Definitions for devices, commands and results. These definitions need to be shared
 * between BIOS and applications invoking BIOS functions. Put into a proper header.
 */

typedef uint32_t device_t;
enum device_enum {
    DEVICE_UART,
    DEVICE_KEYBOARD,
    DEVICE_SD,
    DEVICE_STDIN,
    DEVICE_STDOUT,
};


typedef uint8_t videomode_t;
enum videomode_enum {
    VIDEOMODE_OFF = 0,
    VIDEOMODE_TEXT_40 = 1,
    VIDEOMODE_GRAPHICS_640 = 2,
    VIDEOMODE_GRAPHICS_320 = 3
};


typedef uint32_t command_t;
enum command_enum {
    CMD_INIT_BLOCK_DEVICE,
    CMD_READ_BLOCK,
    CMD_WRITE_BLOCK,
    CMD_AVAILABLE_STREAM,
    CMD_READ_STREAM,
    CMD_WRITE_STREAM,
    CMD_FS_INIT,
    CMD_FS_OPENFILE,
    CMD_FS_CLOSEFILE,
    CMD_FS_READFILE,
    CMD_FS_WRITEFILE,
    CMD_FS_UNLINK,
    CMD_FS_FINDFIRST,
    CMD_FS_FINDNEXT,
    CMD_FS_GETCWD,
    CMD_FS_CHDIR,
    CMD_FS_FREE,
    CMD_FS_SEEK,
    CMD_FS_MKDIR,
    CMD_FS_RENAME,
    CMD_FS_SIZE,
    CMD_FS_TELL,
    CMD_FS_STAT,
    CMD_VIDEO_SETMODE,
    CMD_VIDEO_SETPALETTE
};

typedef int32_t result_t;
enum result_enum {
    RESULT_OK = 0,
    RESULT_ERR = 1,
    RESULT_ERRPARAMS = 2,
    RESULT_NOTFOUND = 3,
    RESULT_DENIED = 4,
    RESULT_TOOMANY = 5,
    RESULT_INVALID = 6,
};

typedef int32_t filehandle_t;
typedef uint8_t filemode_t;

// mode definitions taken from ff.h
#define	MODE_READ				0x01
#define	MODE_WRITE			    0x02
#define	MODE_OPEN_EXISTING	    0x00
#define	MODE_CREATE_NEW		    0x04
#define	MODE_CREATE_ALWAYS	    0x08
#define	MODE_OPEN_ALWAYS		0x10
#define	MODE_OPEN_APPEND		0x30

// attribute definitions taken from ff.h
#define	ATTRIB_RDO	0x01	/* Read only */
#define	ATTRIB_HID	0x02	/* Hidden */
#define	ATTRIB_SYS	0x04	/* System */
#define ATTRIB_DIR	0x10	/* Directory */
#define ATTRIB_ARC	0x20	/* Archive */


// data structure for requesting block device initialization
struct request_init_block_device_t {
    command_t command; // every request needs to have a command_t at the top!
    device_t device;
    uint32_t block_size;
    int32_t blocks;
    result_t result;
};

struct block_device_info_t {
    uint32_t block_size;
    uint32_t blocks;
};


// structure for file information
struct file_info_t {
    uint32_t size;
    uint16_t date;
    uint16_t time;
    char name[13];
    uint8_t attrib;
};



// data structure for block read and write requests
struct request_readwrite_block_t {
    command_t command; // every request needs to have a command_t at the top!
    device_t device;
    uint32_t block;
    uint32_t len;
    result_t result;
    void* buf;
};

// data structure for stream data availability check requests
struct request_available_stream_t {
    command_t command; // every request needs to have a command_t at the top!
    device_t device;
    uint32_t available;
    result_t result;
};

// data structure for stream read and write requests
struct request_readwrite_stream_t {
    command_t command; // every request needs to have a command_t at the top!
    device_t device;
    uint32_t len;
    result_t result;
    void* buf;
};


// data structure for file system init requests
struct request_fs_init_t {
    command_t command; // every request needs to have a command_t at the top!
    device_t device;
    result_t result;
};

// data structure for open file requests
struct request_fs_open_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    filehandle_t* filehandle;
    result_t result;
    filemode_t mode;
};

// data structure for file closing requests
struct request_fs_close_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    result_t result;
};

// data structure for file read requests
struct request_fs_read_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    uint32_t nbytes;
    result_t result;
    uint32_t* readbytes;
    void* buf;
};

// data structure for file write requests
struct request_fs_write_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    uint32_t nbytes;
    result_t result;
    uint32_t* writtenbytes;
    void* buf;
};

// data structure for file/dir unlink requests
struct request_fs_unlink_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    result_t result;
};

// data structure for directory findfirst requests
struct request_fs_findfirst_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    char* pattern;
    struct file_info_t* fileinfo;
    result_t result;
};

// data structure for directory findnext requests
struct request_fs_findnext_t {
    command_t command; // every request needs to have a command_t at the top!
    struct file_info_t* fileinfo;
    result_t result;
};


// data structure for "get current workdir" requests
struct request_fs_getcwd_t {
    command_t command; // every request needs to have a command_t at the top!
    char* buf;
    uint32_t len;
    result_t result;
};

// data structure for "change working directory" requests
struct request_fs_chdir_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    result_t result;
};

// data structure for "report free bytes on FS" requests
struct request_fs_free_t {
    command_t command; // every request needs to have a command_t at the top!
    uint64_t* free;
    result_t result;
};

// data structure for file seek requests
struct request_fs_seek_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    uint32_t position;
    result_t result;
};

// data structure for mkdir requests
struct request_fs_mkdir_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    result_t result;
};

// data structure for file rename requests
struct request_fs_rename_t {
    command_t command; // every request needs to have a command_t at the top!
    char* oldname;
    char* newname;
    result_t result;
};

// data structure for file size requests
struct request_fs_size_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    uint32_t* size;
    result_t result;
};

// data structure for tell requests
struct request_fs_tell_t {
    command_t command; // every request needs to have a command_t at the top!
    filehandle_t fh;
    uint32_t* position;
    result_t result;    
};

// data structure for stat requests
struct request_fs_stat_t {
    command_t command; // every request needs to have a command_t at the top!
    char* path;
    struct file_info_t* fileinfo;
    result_t result;
};

// data structure to set video mode
struct request_video_set_mode_t {
    command_t command; // every request needs to have a command_t at the top!
    void* videobase;
    void* fontbase;
    result_t result;
    videomode_t mode; // is uint8_t
};

// data structure to set video colour palette
struct request_video_set_palette_t {
    command_t command; // every request needs to have a command_t at the top!
    uint8_t* palette;
    result_t result;
};

#endif