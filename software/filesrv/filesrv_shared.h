#ifndef FILESRV_SHARED
#define FILESRV_SHARED
#include <stdint.h>

typedef uint16_t cmd_t;
enum cmd_enum {
    FSERV_DATA = 0,
    FSERV_OPENREAD = 1,
    FSERV_OPENWRITE = 2,
    FSERV_CLOSE = 3,
    FSERV_READ = 4,
    FSERV_WRITE = 5,
    FSERV_LS = 6,
    FSERV_CD = 7,
    FSERV_EXIT = 8,
    FSERV_ERROR = 9,
};


struct baseheader_t {
    cmd_t cmd;
    uint16_t payload_len;        
    uint8_t header_checksum;
    uint8_t payload_checksum;
};

uint8_t checksum8(uint8_t* datptr, uint32_t len);
void prepare_baseheader(struct baseheader_t* head, uint16_t cmd, uint8_t* payload, uint16_t paylen);
int check_baseheader(struct baseheader_t* head);

int send_packet(uint16_t cmd, void* payload, uint32_t payloadlen, int (*read_data)(void*, uint32_t), int (*write_data)(void*, uint32_t));
int receive_packet(struct baseheader_t* head, void* buf, uint32_t len, int (*read_data)(void*, uint32_t), int (*write_data)(void*, uint32_t), int (*payload_callback)(struct baseheader_t* head, void* payload));


#endif