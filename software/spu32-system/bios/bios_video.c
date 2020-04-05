#include "bios_video.h"
#include <stddef.h>

#define TERM_COLS 40
#define TERM_ROWS 30

// standard colour: white text on black background
#define TERM_DEFAULT_COLOUR 0x70

uint32_t row, col;
uint8_t escape;
char escape_buf[4];
uint8_t term_colour;
char term_cursor_save; // for the character the cursor overwrites

void softterm_clear()
{
    char* textbase = (char*)VIDEO_BASE;
    // clear video text buffer;
    for (uint32_t i = 0; i < (TERM_COLS * TERM_ROWS * 2); i += 2) {
        textbase[i] = ' ';
        // set fg colour to light gray, bg colour to black
        textbase[i + 1] = term_colour;
    }
    row = 0;
    col = 0;
}

void softterm_init()
{
    if (VIDEO_MODE != VIDEOMODE_TEXT_40) {
        return;
    }
    escape = 0;
    term_colour = TERM_DEFAULT_COLOUR;
    term_cursor_save = ' ';
    softterm_clear();
}

void softterm_scroll()
{
    char* textbase = (char*)VIDEO_BASE;

    // copy row contents from row below
    for (uint32_t offset = (TERM_COLS * 2); offset < (TERM_COLS * TERM_ROWS * 2); offset++) {
        textbase[offset - (TERM_COLS * 2)] = textbase[offset];
    }

    // clear last line
    for (uint32_t offset = (TERM_ROWS - 1) * (TERM_COLS * 2); offset < (TERM_COLS * TERM_ROWS * 2); offset += 2) {
        textbase[offset] = ' ';
        textbase[offset + 1] = term_colour;
    }

    row--;
}

void softterm_check_cursor()
{
    if (col >= TERM_COLS) {
        row++;
        col = 0;
    }

    while (row >= TERM_ROWS) {
        softterm_scroll();
    }
}

void softterm_change_colours() {
    uint8_t colour = escape_buf[sizeof(escape_buf) - 2] - '0';
    uint8_t cmd = escape_buf[sizeof(escape_buf) - 3];

    colour &= 0b0111;

    if(cmd == '3') {
        // change foreground colour
        term_colour &= 0x0F;
        term_colour |= (colour << 4);
    } else if(cmd == '4') {
        // change background colour
        term_colour &= 0xF0;
        term_colour |= colour;
    } else {
        // reset to default colour
        term_colour = TERM_DEFAULT_COLOUR;
    }
}

void softterm_write_char(char c)
{
    char* textbase = (char*)VIDEO_BASE;
    uint32_t offset = (2 * ((row * TERM_COLS) + col));

    // make cursor invisible
    textbase[offset] = term_cursor_save;

    if (escape) {

        for(uint32_t i = 1; i < sizeof(escape_buf); ++i) {
            escape_buf[i-1] = escape_buf[i];
        }
        escape_buf[sizeof(escape_buf) - 1] = c;


        switch (c) {
        case 'm': // graphics/color
            softterm_change_colours();
            escape = 0;
            break;
        case 'J': // clear screen
            softterm_clear();
            escape = 0;
            break;
        case 'H': // Home
            row = 0;
            col = 0;
            escape = 0;
            break;
        }

    } else {
        if (c == '\x1B') {
            escape = 1;
        } else if (c == '\n') {
            row++;
            col = 0;
        } else if (c == '\r') {
            col = 0;
        } else if (c == '\b') {
            if(col > 0) {
                col--;
            } else if(row > 0) {
                row--;
                col = TERM_COLS - 1;
            }
        } else {
            textbase[offset] = c;
            textbase[offset + 1] = term_colour; // light gray on black background
            col++;
        }
    }

    softterm_check_cursor();
    // draw cursor
    offset = (2 * ((row * TERM_COLS) + col));
    term_cursor_save = textbase[offset];
    textbase[offset] = 0xDB;
}

result_t bios_video_set_mode(videomode_t mode, void* videobase, void* fontbase)
{

    result_t result;

    VIDEO_MODE = mode;
    VIDEO_BASE = (uint32_t)videobase;
    VIDEO_FONT = (uint32_t)fontbase;

    switch (mode) {
    case VIDEOMODE_TEXT_40:
        softterm_init();
    case VIDEOMODE_OFF:
    case VIDEOMODE_GRAPHICS_640:
    case VIDEOMODE_GRAPHICS_320:
        result = RESULT_OK;
        break;
    default:
        result = RESULT_ERR;
    }

    if (result != RESULT_OK) {
        return result;
    }

    return result;
}

result_t bios_video_set_palette(uint8_t* palette)
{
    uint8_t idx = 0;
    while (1) {
        uint32_t offset = idx * 3;
        uint8_t r = palette[offset];
        uint8_t g = palette[offset + 1];
        uint8_t b = palette[offset + 2];

        VIDEO_PALETTE = (idx << 24 | (r << 16) | (g << 8) | b);

        if (idx == 0xFF) {
            break;
        }
        idx++;
    }

    return RESULT_OK;
}

uint32_t bios_video_get_videobase()
{
    return VIDEO_BASE;
}

uint32_t bios_video_get_fontbase()
{
    return VIDEO_FONT;
}

uint32_t bios_video_getcols()
{
    switch (VIDEO_MODE) {
    VIDEOMODE_TEXT_40:
        return 40;

    VIDEOMODE_GRAPHICS_640:
        return 640;

    VIDEOMODE_GRAPHICS_320:
        return 320;

    default:
        return 0;
    }
}

uint32_t bios_video_getrows()
{
    switch (VIDEO_MODE) {
    VIDEOMODE_TEXT_40:
        return 30;

    VIDEOMODE_GRAPHICS_640:
        return 480;

    VIDEOMODE_GRAPHICS_320:
        return 240;

    default:
        return 0;
    }
}

void bios_video_write(struct request_readwrite_stream_t* request)
{
    if (VIDEO_MODE != VIDEOMODE_TEXT_40) {
        return;
    }

    uint8_t* buffer = request->buf;
    for (uint32_t i = 0; i < request->len; ++i) {
        softterm_write_char((char)buffer[i]);
    }
}