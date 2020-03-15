#include "bios_video.h"

result_t bios_video_set_mode(videomode_t mode, void* videobase, void* fontbase)
{

    result_t result;
    switch (mode) {
    case VIDEOMODE_OFF:
    case VIDEOMODE_TEXT_40:
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

    VIDEO_MODE = mode;
    VIDEO_BASE = (uint32_t) videobase;
    VIDEO_FONT = (uint32_t) fontbase;

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