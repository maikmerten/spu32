#include <stdint.h>
#include <libtinyc.h>
#include "devices.h"

#include "bios_shared.h"
#include "bios_spi.h"
#include "bios_sdcard.h"
#include "bios_uart.h"
#include "bios_fatfs.h"

// ------------------------------------------------------------------------------------

/// START OF BIOS CODE ///

void bios_init_block_device(struct request_init_block_device_t* req);
void bios_read_block(struct request_readwrite_block_t* req);
void bios_write_block(struct request_readwrite_block_t* req);
void bios_available_stream(struct request_available_stream_t* req);
void bios_read_stream(struct request_readwrite_stream_t* req);
void bios_write_stream(struct request_readwrite_stream_t* req);
void bios_fs_init(struct request_fs_init_t* req);
void bios_fs_open_file(struct request_fs_open_t* request_addr);
void bios_fs_close_file(struct request_fs_close_t* request_addr);
void bios_fs_read_file(struct request_fs_read_t* request);
void bios_fs_write_file(struct request_fs_write_t* request);
void bios_fs_unlink(struct request_fs_unlink_t* request);
void bios_fs_findfirst(struct request_fs_findfirst_t* request);
void bios_fs_findnext(struct request_fs_findnext_t* request);
void bios_fs_getcwd(struct request_fs_getcwd_t* request);
void bios_fs_chdir(struct request_fs_chdir_t* request);
void bios_fs_free(struct request_fs_free_t* request);
void bios_fs_seek(struct request_fs_seek_t* request);
void bios_fs_mkdir(struct request_fs_mkdir_t* request);
void bios_fs_rename(struct request_fs_rename_t* request);
void bios_fs_size(struct request_fs_size_t* request);
void bios_fs_tell(struct request_fs_tell_t* request);
void bios_fs_stat(struct request_fs_stat_t* request);

/**
 * This is the interrupt service routine. Yeah, we can write this in C.
 * BIOS requests are done using ecall software-interrupts. In this routine, we need
 * to quickly determine what sort of interrupt (hardware? software? What sort of software
 * interrupt?) happened and act accordingly.
 */

void bios_isr()__attribute((interrupt));
void bios_isr() {
    // Retrieve contents of register t0 and put into into variable request_addr.
    // If this is a BIOS request, t0 will contain a memory address where the
    // request is located.
    uint32_t request_addr;
    asm("or %[result], t0, t0" : [result] "=r" (request_addr) );


    // retrieve interrupt cause
    uint32_t cause;
    asm("csrrw %[result], 0xFC1, zero" : [result] "=r" (cause) );

    if(cause & 0x80000000) {
        // hardware interrupt

        // TODO: do something exciting with hardware interrupts. Those are disabled
        // on reset, so we shouldn't encounter them without activating them first.

    } else {
        // software interrupt
        switch(cause & 0xF) {

            case 0xB: {
                // ecall instruction - "environment call"
                // BIOS action was requested! Find out what command was issued
                // and call the respective functions for fun an profit!
            
                // arg0 has address of request structure, first member of that
                // structure needs to be a command_t
                command_t command = *((command_t*) request_addr);
            
                switch(command) {
                    case CMD_INIT_BLOCK_DEVICE: {
                        bios_init_block_device((void*) request_addr);
                        break;
                    }
                    case CMD_READ_BLOCK: {
                        bios_read_block((void*) request_addr);
                        break;
                    }
                    case CMD_WRITE_BLOCK: {
                        bios_write_block((void*) request_addr);
                        break;
                    }
                    case CMD_AVAILABLE_STREAM: {
                        bios_available_stream((void*) request_addr);
                        break;
                    }
                    case CMD_READ_STREAM: {
                        bios_read_stream((void*) request_addr);
                        break;
                    }
                    case CMD_WRITE_STREAM: {
                        bios_write_stream((void*) request_addr);
                        break;
                    }
                    case CMD_FS_INIT: {
                        bios_fs_init((void*) request_addr);
                        break;
                    }
                    case CMD_FS_OPENFILE: {
                        bios_fs_open_file((void*) request_addr);
                        break;
                    }
                    case CMD_FS_CLOSEFILE: {
                        bios_fs_close_file((void*) request_addr);
                        break;
                    }
                    case CMD_FS_READFILE: {
                        bios_fs_read_file((void*) request_addr);
                        break;
                    }
                    case CMD_FS_WRITEFILE: {
                        bios_fs_write_file((void*) request_addr);
                        break;
                    }
                    case CMD_FS_UNLINK: {
                        bios_fs_unlink((void*) request_addr);
                        break;
                    }
                    case CMD_FS_FINDFIRST: {
                        bios_fs_findfirst((void*) request_addr);
                        break;
                    }
                    case CMD_FS_FINDNEXT: {
                        bios_fs_findnext((void*) request_addr);
                        break;
                    }
                    case CMD_FS_GETCWD: {
                        bios_fs_getcwd((void*) request_addr);
                        break;
                    }
                    case CMD_FS_CHDIR: {
                        bios_fs_chdir((void*) request_addr);
                        break;
                    }
                    case CMD_FS_FREE: {
                        bios_fs_free((void*) request_addr);
                        break;
                    }
                    case CMD_FS_SEEK: {
                        bios_fs_seek((void*) request_addr);
                        break;
                    }
                    case CMD_FS_MKDIR: {
                        bios_fs_mkdir((void*) request_addr);
                        break;
                    }
                    case CMD_FS_RENAME: {
                        bios_fs_rename((void*) request_addr);
                        break;
                    }
                    case CMD_FS_SIZE: {
                        bios_fs_size((void*) request_addr);
                        break;
                    }
                    case CMD_FS_TELL: {
                        bios_fs_tell((void*) request_addr);
                        break;
                    }
                    case CMD_FS_STAT: {
                        bios_fs_stat((void*) request_addr);
                        break;
                    }
                    default: {
                        // Unknown command requested! Panic? Panic!
                    }
                }
                break;
            }

            case 0x3: {
                // ebreak instruction

                // ebreak instructions are for debugging and stuff. We don't make
                // mistakes, so we don't need to debug. Well, actually, TODO.
                break;
            }
            default: {
                // invalid instruction

                // The CPU has seen horrible things. Emulate unknown but valid instructions.
                // Or panic. Yeah, just panic.

                // TODO: Panic.
                break;
            }
        }

        // advance exception PC to next instruction
        uint32_t epc = 0;
        // read exception PC
	    asm("csrrw %[result], 0xFC2, zero" : [result] "=r" (epc) );
        // increment by four
        epc += 4;
        // write incremented exception PC to MSR
        asm("csrrw zero, 0x7C2, %[value]" : : [value] "r" (epc) );
    }
}

// --- BIOS call implementations ---//


void bios_init_block_device(struct request_init_block_device_t* request) {
    request->result = RESULT_ERR;

    switch(request->device) {
        case DEVICE_SD: {
            request->result = bios_sd_init(request);
            break;
        }
        default: {
            request->result = RESULT_ERR;
        }
    }
}


// function to handle block read requests
void bios_read_block(struct request_readwrite_block_t* request) {
    // assume error for now
    request->result = RESULT_ERR;

    switch(request->device) {
        case DEVICE_SD: {
            if(request->len != 512) {
                return;
            }
            request->result = bios_sd_read_block(request->block, request->buf);
       
        }
    }
}

// function to handle block write requests
void bios_write_block(struct request_readwrite_block_t* request) {
    // assume error for now
    request->result = RESULT_ERR;

    switch(request->device) {
        case DEVICE_SD: {
            if(request->len != 512) {
                return;
            }
            request->result = bios_sd_write_block(request->block, request->buf);
        }
    }
}

void bios_available_stream(struct request_available_stream_t* request) {
    switch(request->device) {
        case DEVICE_UART: {
            request->available = bios_uart_available();
            request->result = RESULT_OK;
            return;
        }
        default: {
            request->result = RESULT_ERR;
        }
    }
    
}

// function to handle stream read requests
void bios_read_stream(struct request_readwrite_stream_t* request) {
    switch(request->device) {
        case DEVICE_STDIN:
        case DEVICE_UART: {
            bios_uart_read(request);
            request->result = RESULT_OK;
            return;
        }
        default: {
            request->result = RESULT_ERR;
        }
    }
}

// function to handle stream write requests
void bios_write_stream(struct request_readwrite_stream_t* request) {
    switch(request->device) {
        case DEVICE_STDOUT:
        case DEVICE_UART: {
            bios_uart_write(request);
            request->result = RESULT_OK;
            return;
        }
        default: {
            request->result = RESULT_ERR;
        }
    }
}


// function to init  file system
void bios_fs_init(struct request_fs_init_t* request) {
    switch(request->device) {
        case DEVICE_SD: {
            request->result = bios_fatfs_init();
            return;
        }
        default: {
            request->result = RESULT_ERR;
        }
    }
}

// function to open files
void bios_fs_open_file(struct request_fs_open_t* request) {
    request->result = bios_fatfs_open(request->filehandle, request->path, request->mode);
}

// function to close files
void bios_fs_close_file(struct request_fs_close_t* request) {
    request->result = bios_fatfs_close(request->fh);
}

// function to read from a file
void bios_fs_read_file(struct request_fs_read_t* request) {
    request->result = bios_fatfs_read(request->fh, request->buf, request->nbytes, request->readbytes);
}

// function to write to a file
void bios_fs_write_file(struct request_fs_write_t* request) {
    request->result = bios_fatfs_write(request->fh, request->buf, request->nbytes, request->writtenbytes);
}

// function to unlink (=delete) files and directories
void bios_fs_unlink(struct request_fs_unlink_t* request) {
    request->result = bios_fatfs_unlink(request->path);
}

// function to start directory listings
void bios_fs_findfirst(struct request_fs_findfirst_t* request) {
    request->result = bios_fatfs_findfirst(request->path, request->pattern, request->fileinfo);
}

// functions to continue directory listings
void bios_fs_findnext(struct request_fs_findnext_t* request) {
    request->result = bios_fatfs_findnext(request->fileinfo);
}

// function to retrieve current workdir
void bios_fs_getcwd(struct request_fs_getcwd_t* request) {
    request->result = bios_fatfs_getcwd(request->buf, request->len);
}

// function to change current workdir
void bios_fs_chdir(struct request_fs_chdir_t* request) {
    request->result = bios_fatfs_chdir(request->path);
}

// function to retrieve number of free bytes on FS
void bios_fs_free(struct request_fs_free_t* request) {
    request->result = bios_fatfs_free(request->free);
}

// function for file seeks
void bios_fs_seek(struct request_fs_seek_t* request) {
    request->result = bios_fatfs_seek(request->fh, request->position);
}

// function to create directories on FS
void bios_fs_mkdir(struct request_fs_mkdir_t* request) {
    request->result = bios_fatfs_mkdir(request->path);
}

// function to rename
void bios_fs_rename(struct request_fs_rename_t* request) {
    request->result = bios_fatfs_rename(request->oldname, request->newname);
}

// function to retrieve file size
void bios_fs_size(struct request_fs_size_t* request) {
    request->result = bios_fatfs_size(request->fh, request->size);
}

// function determine current position within file
void bios_fs_tell(struct request_fs_tell_t* request) {
    request->result = bios_fatfs_tell(request->fh, request->position);
}

// function to retrieve file information
void bios_fs_stat(struct request_fs_stat_t* request) {
    request->result = bios_fatfs_stat(request->path, request->fileinfo);
}

/// END OF BIOS CODE ///




