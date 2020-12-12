#include "filesrv_shared.h"

// BSD-style 8-bit checksum
uint8_t checksum8(uint8_t* datptr, uint32_t len)
{
    uint8_t sum = 0;
    for (uint32_t i = 0; i < len; i++) {
        sum = (sum >> 1) | ((sum & 1) << 7);
        sum += datptr[i];
    }
    return sum;
}

void prepare_baseheader(struct baseheader_t* head, uint16_t cmd, uint8_t* payload, uint16_t paylen)
{
    uint8_t payload_checksum = checksum8(payload, paylen);

    head->cmd = cmd;
    head->header_checksum = 0;
    head->payload_len = paylen;
    head->payload_checksum = payload_checksum;

    struct baseheader_t h; // used for sizeof
    uint8_t header_checksum = checksum8((void*)head, sizeof h);
    head->header_checksum = header_checksum;
}

int check_baseheader(struct baseheader_t* head)
{
    struct baseheader_t h;

    // construct pseudo-header for checksum computation
    h.cmd = head->cmd;
    h.header_checksum = 0;
    h.payload_len = head->payload_len;
    h.payload_checksum = head->payload_checksum;

    if (head->header_checksum != checksum8((void*)&h, sizeof h)) {
        return 1;
    }
    return 0;
}


int send_packet(uint16_t cmd, void* payload, uint32_t payloadlen, int (*read_data)(void*, uint32_t), int (*write_data)(void*, uint32_t))
{
    struct baseheader_t head;
    int error = 0;
    int res = 0;

    uint8_t ack;

    prepare_baseheader(&head, cmd, payload, payloadlen);
    uint8_t head_checksum = head.header_checksum;
    uint8_t payload_checksum = head.payload_checksum;

    res = write_data(&head, sizeof head);

    // receive header ack
    res = read_data(&ack, 1);

    if (ack != head_checksum) {
        error = 1;
    }

    // send payload
    res = write_data(payload, payloadlen);

    // receive payload ack
    res = read_data(&ack, 1);
    if (ack != payload_checksum) {
        error = 2;
    }

    return error;
}


int receive_packet(struct baseheader_t* head, void* buf, uint32_t len, int (*read_func)(void*, uint32_t), int (*write_func)(void*, uint32_t), int (*payload_callback)(struct baseheader_t* head, void* payload)) {
    int error = 0;
    struct baseheader_t h; // used for sizeof
    
    // receive base header
    read_func(head, sizeof h);
    error = check_baseheader(head);
    if(error) {
        return 1;
    }

    // clear buffer to ensure null-terminated strings
    for(uint32_t i = 0; i < len; i++) {
        ((uint8_t*)buf)[i] = 0;
    }

    uint8_t head_checksum = head->header_checksum;
    uint16_t payload_len = head->payload_len;

    if(payload_len > len) {
        // payload too big for provided buffer
        head_checksum++;
        write_func(&head_checksum, 1);
        return 2;
    }

    // ACK base header
    write_func(&head_checksum, 1);

    // receive payload
    read_func(buf, payload_len);

    uint8_t payload_checksum = checksum8(buf, payload_len);
    if(payload_checksum != head->payload_checksum) {
        write_func(&payload_checksum, 1);
        return 3;
    }

    // Before ACKing payload, process packet
    error = payload_callback(head, buf);

    // in case of error modify checksum to signal error
    if(error) {
        payload_checksum++;
    }

    // ACK payload
    write_func(&payload_checksum, 1);


    return 0;
}