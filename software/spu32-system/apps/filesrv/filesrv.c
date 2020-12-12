#include "../../filesrv/filesrv_shared.h"
#include <libspu32.h>
#include <libtinyc.h>
#include <stdint.h>

// evil global variables here
// evil filehandle
filehandle_t fh;

static int read_func(void* buf, uint32_t len)
{
    result_t res = bios_stream_read(DEVICE_UART, buf, len);
    if (res != RESULT_OK) {
        return 1;
    }
    return 0;
}

static int write_func(void* buf, uint32_t len)
{
    result_t res = bios_stream_write(DEVICE_UART, buf, len);
    if (res != RESULT_OK) {
        return 1;
    }
    return 0;
}

int open_file(char* file, int write)
{
// mode definitions taken from ff.h
#define MODE_READ 0x01
#define MODE_WRITE 0x02
#define MODE_CREATE_ALWAYS 0x08

    result_t res = bios_fs_open(&fh, file, write ? (MODE_WRITE | MODE_CREATE_ALWAYS) : MODE_READ);
    if (res != RESULT_OK) {
        printf("could not open file %s\n", file);
    }
    return res == RESULT_OK ? 0 : 1;
}

int write_file(uint8_t* payload, uint32_t len)
{
    uint32_t written = 0;
    result_t res = bios_fs_write(fh, (void*)payload, len, &written);
    if (res != RESULT_OK || written != len) {
        // write failed
        return 1;
    }
    return 0;
}

int read_file()
{
    uint8_t buf[2048];
    uint32_t read;
    result_t res = bios_fs_read(fh, buf, sizeof buf, &read);
    if (res != RESULT_OK) {
        // read failed
        send_packet(FSERV_ERROR, buf, 0, &read_func, &write_func);
        return 1;
    }
    int error = send_packet(FSERV_DATA, buf, read, &read_func, &write_func);
    return error;
}

int close_file()
{
    result_t res = bios_fs_close(fh);
    return res == RESULT_OK ? 0 : 1;
}

int payload_callback(struct baseheader_t* head, void* payload)
{
    int error = 0;
    uint16_t cmd = head->cmd;
    uint16_t payloadlen = head->payload_len;

    switch (cmd) {
    case FSERV_OPENREAD:
    case FSERV_OPENWRITE:
        printf("\nopen file: %s\n", payload);
        error = open_file(payload, cmd == FSERV_OPENWRITE ? 1 : 0);
        break;
    case FSERV_WRITE:
        printf(".");
        error = write_file(payload, payloadlen);
        break;
    case FSERV_CLOSE:
        printf("\nclosing file\n");
        error = close_file(&fh);
        break;
    }

    return error;
}

int main()
{

    result_t res;
    struct baseheader_t head;
    uint8_t payload[2048];

    // evil hack: disable UART reset by setting all board LEDs
    uint8_t* leds = (uint8_t*)0xFFFFFFFF;
    *leds = 0xFF;

    int run = 1;
    int error = 0;

    while (run) {
        receive_packet(&head, payload, sizeof payload, &read_func, &write_func, &payload_callback);

        uint16_t cmd = head.cmd;

        // if needed, send response packets
        switch (cmd) {
        case FSERV_READ:
            printf(">");
            error = read_file(&fh);
            break;
        case FSERV_EXIT:
            run = 0;
            break;
        }

        if (error) {
            error = 0;
            // TODO: send ERROR packet
        }
    }

    close_file();

    int now = get_milli_time();
    while (get_milli_time() - now < 500) { }

    *leds = 0;

    return 0;
}
