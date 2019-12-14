#include <stdint.h>

#ifndef STDLIB
#include <libtinyc.h>
#include <libspu32.h>
#include "../asm/devices.h"
#else
#include <stdio.h>
#include <stdlib.h>
void read_string(char *buf, int n, char echo) {
    fgets(buf, n+1, stdin);
}

int get_prng_value() {
    return rand();
}

int parse_int(char *str) {
        int result = 0;
        char negative = 0;
        while(1) {
                char c = *str;
                if(!c) break;
                if(c == '-') {
                        negative = 1;
                }

                if(c >= '0' && c <= '9') {
                        result *= 10;
                        result += (c - '0');
                }

                str++;
        }

        if(negative) {
                result *= -1;
        }

        return result;
}
#endif

#define ANSI_CLEAR_SCREEN  "\x1b[2J"
#define ANSI_HOME          "\x1b[H"
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_MAGENTA "\x1b[35m"
#define ANSI_COLOR_CYAN    "\x1b[36m"
#define ANSI_COLOR_RESET   "\x1b[0m"
#define ANSI_BG_RED        "\x1b[41m"
#define ANSI_BG_BLUE       "\x1b[44m"

// dimensions of playing field
#define SIZEX 6
#define MAXX 5
#define SIZEY 5
#define MAXY 4

// player number of AI
#define PLAYERAI 2


// -----------------
// game.c
// -----------------


unsigned char ki;
unsigned char playerplayed[3];

// --------------------
// field.c
// --------------------

void setAtoms(char f[SIZEX][SIZEY], char atoms, char x, char y) {
    atoms = atoms > 4 ? 4 : atoms;
    f[x][y] = (f[x][y] & 0xF0) | atoms;
}

char getAtoms(char f[SIZEX][SIZEY], char x, char y) {
    return f[x][y] & 0x0F;
}

void setOwner(char f[SIZEX][SIZEY], char owner, char x, char y) {
    owner &= 0x0F;
    owner = owner << 4;
    f[x][y] = (f[x][y] & 0x0F) | owner;
}

char getOwner(char f[SIZEX][SIZEY], char x, char y) {
    return (f[x][y] & 0xF0) >> 4;
}

char getOwnerCount(char f[SIZEX][SIZEY], char owner) {
    char x,y,count;
    count = 0;
    for(x = 0; x < SIZEX; ++x) {
        for(y = 0; y < SIZEY; ++y) {
            if(getOwner(f,x,y) == owner) {
                count += getAtoms(f, x, y);
            }
        }
    }
    return count;
}



void clearField(char field[SIZEX][SIZEY]) {
    char x,y;
    for(x = 0; x < SIZEX; ++x) {
        for(y = 0; y < SIZEY; ++y) {
            setAtoms(field, 0, x, y);
            setOwner(field, 0, x, y);
        }
    }
}

char getCapacity(char x, char y) {
    char capacity = 3;
    if(x == 0 || x == MAXX) --capacity;
    if(y == 0 || y == MAXY) --capacity;
    return capacity;
}


void spreadAtoms(char f[SIZEX][SIZEY], char x, char y, char p) {
    char i;
    if(x > 0) {
        i = x - 1;
        setAtoms(f, getAtoms(f, i, y) + 1, i, y);
        setOwner(f, p, i, y);
    }
    if(y > 0) {
        i = y - 1;
        setAtoms(f, getAtoms(f, x, i) + 1, x, i);
        setOwner(f, p, x, i);
    }
    if(x < MAXX) {
        i = x + 1;
        setAtoms(f, getAtoms(f, i, y) + 1, i, y);
        setOwner(f, p, i, y);
    }
    if(y < MAXY) {
        i = y + 1;
        setAtoms(f, getAtoms(f, x, i) + 1, x, i);
        setOwner(f, p, x, i);
    }
}

void drawField(char field[SIZEX][SIZEY], char clear);
void react(char f[SIZEX][SIZEY], char draw) {
    char stable,count,x,y,player,players;
    stable = 0;
    while(!stable) {
        stable = 1;
        players = 0;
        for(x = 0; x < SIZEX; ++x) {
            for(y = 0; y < SIZEY; ++y) {
                count = getAtoms(f, x, y);
                player = getOwner(f, x, y);
                players |= player;
                if(count > getCapacity(x, y)) {
                    stable = 0;
                    spreadAtoms(f, x, y, player);
                    setAtoms(f, 0, x, y);
                    setOwner(f, 0, x, y);
                    if(draw) {
                        drawField(f, 0);
                    }
                }
            }
        }
        
        if(players < 3) {
            // we only got player 1 or 2 left, no need for further reaction
            stable = 1;
        }
    }
}

void putAtom(char f[SIZEX][SIZEY], char p, char x, char y, char draw) {
    char atoms;
    char owner = getOwner(f, x, y);
    if(owner != 0 && owner != p) { return; }
    atoms = getAtoms(f, x, y) + 1;
    setAtoms(f, atoms, x, y);
    setOwner(f, p, x, y);
    //if(draw) drawAtoms(x, y);
}


//-----------
// draw routines
// ----------


#ifndef STDLIB

#define VGA_BASE *((volatile uint32_t*)DEV_VGA_BASE)
#define VGA_MODE *((volatile uint8_t*)DEV_VGA_MODE)
#define VGA_VISIBLE *((volatile uint8_t*)DEV_VGA_LINE_VISIBLE)

// -----------------
// graphics definitions
// -----------------

static uint8_t graphics_tile[] = {
    30,29,29,29,29,29,29,29,29,29,29,29,29,29,29,29,
    29,29,29,29,29,29,29,29,29,29,29,29,29,29,29,24,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    29,26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,
    26,26,26,26,26,26,26,26,26,26,26,26,26,26,26,22,
    24,22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,
    22,22,22,22,22,22,22,22,22,22,22,22,22,22,22,20
};

static char graphics_atom_blue[] = {
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,24,129,105,129,129,9,255,255,255,255,255,
	255,255,255,25,104,104,104,1,9,9,55,56,255,255,255,255,
	255,255,255,104,104,104,1,104,9,79,57,9,56,255,255,255,
	255,255,25,177,104,1,104,9,79,30,103,79,55,129,255,255,
	255,255,21,177,105,105,9,9,56,103,81,79,1,129,255,255,
	255,255,200,177,176,104,104,1,105,56,79,56,9,127,255,255,
	255,255,200,176,105,177,104,104,1,9,9,104,1,127,255,255,
	255,255,152,176,176,127,127,105,104,1,104,1,104,129,255,255,
	255,255,24,176,176,177,127,177,105,104,1,104,1,255,255,255,
	255,255,255,20,176,176,176,105,176,105,104,104,152,255,255,255,
	255,255,255,255,20,176,176,176,177,177,105,152,255,255,255,255,
	255,255,255,255,255,24,152,200,200,21,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
};


static char graphics_atom_red[] = {
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,255,4,64,64,64,255,255,255,255,255,255,
	255,255,255,255,160,4,4,4,41,39,41,12,255,255,255,255,
	255,255,255,160,4,4,4,12,12,88,64,12,12,255,255,255,
	255,255,255,112,112,4,12,12,88,30,89,64,42,12,255,255,
	255,255,160,112,4,4,4,12,64,89,87,88,12,64,255,255,
	255,255,112,112,112,4,4,4,64,64,88,64,42,12,255,255,
	255,255,112,184,112,112,4,4,4,12,12,39,12,12,255,255,
	255,255,184,184,184,112,112,4,4,4,39,4,41,160,255,255,
	255,255,255,184,112,184,112,112,4,4,4,4,4,255,255,255,
	255,255,255,160,184,112,184,112,112,112,112,4,136,255,255,255,
	255,255,255,255,160,184,112,184,112,112,112,160,255,255,255,255,
	255,255,255,255,255,255,234,185,185,160,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
	255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
};



void clearVGA(uint32_t vga_base) {
    uint32_t* vga_ptr = (uint32_t*) vga_base;
    for(uint32_t i = 0; i < (320 * 240 / 4); ++i) {
        *vga_ptr++ = 0;
    }
}

void drawTileVGA(uint32_t vga_base, uint32_t x, uint32_t y) {
    vga_base += (y * 320) + x;
    uint32_t* vga_ptr = (uint32_t*) vga_base;
    uint32_t* tile_ptr = (uint32_t*) graphics_tile;
    for(uint32_t row = 0; row < 32; ++row) {
        for(uint32_t col = 0; col < (32/4); ++col) {
            *vga_ptr++ = *tile_ptr++;
        }
        vga_ptr += ((320 - 32)/4);
    }
}

void drawAtomVGA(uint32_t vga_base, char player, uint32_t x, uint32_t y) {
    vga_base += (y * 320) + x;
    // enable transparency for 0xFF;
    vga_base |= 0x80000000;


    uint32_t* vga_ptr = (uint32_t*)vga_base;
    // enable transparency for 0xFF
    vga_ptr += 0x80000000;
    uint32_t* atom_ptr = (uint32_t*)(player == 1 ? graphics_atom_red : graphics_atom_blue);
    for(uint32_t row = 0; row < 16; ++row) {
        for(uint32_t col = 0; col < (16/4); ++col) {
            *vga_ptr++ = *atom_ptr++;
        }
        vga_ptr += ((320 - 16)/4);
    }
}


void drawAtomsVGA(uint32_t vga_base, char player, char atoms, uint32_t x, uint32_t y) {
    if(atoms >= 1) {
        drawAtomVGA(vga_base, player, x, y);
    }
    if(atoms >= 2) {
        drawAtomVGA(vga_base, player, x + 16, y);
    }
    if(atoms >= 3) {
        drawAtomVGA(vga_base, player, x , y + 16);
    }
    if(atoms >= 4) {
        drawAtomVGA(vga_base, player, x + 16 , y + 16);
    }
    
}

void drawRowVGA(uint32_t vga_base, char field[SIZEX][SIZEY], char y) {
    char x;
    for(x = 0; x < SIZEX; ++x) {
        char a = getAtoms(field, x, y);
        char p = getOwner(field, x, y);

        uint32_t vga_x = (x * 32) + 64;
        uint32_t vga_y = (y * 32) + 32;

        drawTileVGA(vga_base, vga_x, vga_y);
        drawAtomsVGA(vga_base, p, a, vga_x, vga_y);
        if(p == 1) {
            //printf(ANSI_BG_RED);
        } else if (p == 2)  {
            //printf(ANSI_BG_BLUE);
        } else {
            //printf(ANSI_COLOR_RESET);
        }
    }
   
}

uint8_t vga_flip;

void drawFieldVGA(char field[SIZEX][SIZEY], char clear) {
    uint32_t vga_base;

    if(vga_flip) {
        vga_base = (128 * 1024);
        vga_flip = 0;
    } else {
        vga_base = (256 * 1024);
        vga_flip = 1;
    }


    //if(clear) {
        clearVGA(vga_base);
    //}

    for(uint32_t y = 0; y < SIZEY; ++y) {
        drawRowVGA(vga_base, field, y);
    }

    while(VGA_VISIBLE) {}

    VGA_BASE = vga_base;
    VGA_MODE = 3;
}

#endif



void drawLegend() {
    char c = 'a';
    printf("\n\r     ");
    printf(ANSI_COLOR_YELLOW);
    for(char i = 0; i < SIZEX; ++i) {
        printf("  %c  ", c++);
    }
    printf(ANSI_COLOR_YELLOW);
    printf("\n\r\n\r");
    printf(ANSI_COLOR_RESET);
}


void drawRow(char field[SIZEX][SIZEY], char y) {
    char x;
    for(int line = 0; line < 3; ++line) {
        printf(ANSI_COLOR_YELLOW);
        printf(line & 0x1 ? "  %d  " : "     ", (y+1));
        printf(ANSI_COLOR_RESET);
        for(x = 0; x < SIZEX; ++x) {
            char a = getAtoms(field, x, y);
            char p = getOwner(field, x, y);
            if(p == 1) {
               printf(ANSI_BG_RED);
            } else if (p == 2)  {
                printf(ANSI_BG_BLUE);
            } else {
                printf(ANSI_COLOR_RESET);
            }
            printf(line & 0x1 ? "  %d  " : "     ", a);
        }
        printf(ANSI_COLOR_RESET);
        printf(ANSI_COLOR_YELLOW);
        printf(line & 0x1 ? "  %d\n\r" : "\n\r", (y+1));
        printf(ANSI_COLOR_RESET);
    }
}


void drawField(char field[SIZEX][SIZEY], char clear) {
#ifndef STDLIB
    drawFieldVGA(field, clear);
#endif

    if(clear) {
        printf(ANSI_CLEAR_SCREEN);
    }
    printf(ANSI_HOME);
    char y;
    drawLegend();
    for(y = 0; y < SIZEY; ++y) {
        drawRow(field, y);
    }
    drawLegend();
}


// -----------------
// input
// -----------------

int readPlayerMove(char f[SIZEX][SIZEY], char p) {
    char buf[3];
    char x, y;

    printf(p == 1 ? ANSI_BG_RED : ANSI_BG_BLUE);
    printf("\r\nPlayer %d, your move:", p);
    printf(ANSI_COLOR_RESET);
    printf(" ");
    read_string(buf, sizeof(buf), 1);
    printf("\033[3D   \r\n"); // move cursor back and remove input

    char c = 'a';
    x = 0;
    while(c != buf[0]) {
        c++;
        x++;
        if(x > MAXX) {
            x = 0;
            return -1;
            break;
        }
    }

    int parsed = parse_int(buf);
    if(parsed < 1 || parsed > SIZEY) {
        return -1;
    }

    y = (char) (parsed - 1);

    char owner = getOwner(f, x, y);
    if(owner != p && owner != 0) {
        return -1;
    }
    
    return (x << 8) | y;
}

// --------------------
// AI
// --------------------

char isCritical(char f[SIZEX][SIZEY], char x, char y) {
    if(getAtoms(f, x, y) == getCapacity(x, y)) {
        return 1;
    }
    return 0;
}


char computeDanger(char f[SIZEX][SIZEY], char p, char x, char y) {
    char tmp;
    char danger = 0;

    if(x > 0) {
        tmp = x - 1;
        if(getOwner(f, tmp, y) != p) danger += isCritical(f, tmp, y);
    }
    if(y > 0) {
        tmp = y - 1;
        if(getOwner(f, x, tmp) != p) danger += isCritical(f, x, tmp);
    }
    if(x < MAXX) {
        tmp = x + 1;
        if(getOwner(f, tmp, y) != p) danger += isCritical(f, tmp, y);
    }
    if(y < MAXY) {
        tmp = y + 1;
        if(getOwner(f, x, tmp) != p) danger += isCritical(f, x, tmp);
    }

    return danger;
}

char countEndangered(char f[SIZEX][SIZEY], char p) {
    unsigned char x,y,danger;
    danger = 0;
    for(x = 0; x < SIZEX; ++x) {
        for(y = 0; y < SIZEY; ++y) {
            if(getOwner(f, x, y) == p && computeDanger(f, p, x, y)) ++danger;
        }
    }
    return danger;
}

signed int evaluateField(char f[SIZEX][SIZEY], char p) {
    unsigned char x,y,owner,otherplayer,otherfields;
    int score = 0;
    otherfields = 0;
    otherplayer = p == 1 ? 2 : 1;
    for(x = 0; x < SIZEX; ++x) {
        for(y = 0; y < SIZEY; ++y) {
            owner = getOwner(f, x, y);
            if(owner == p) {
                 // the more cells, the better, but prefer corners and edges
                score += 4 - getCapacity(x, y);
                // small bonus for fields that are ready to explode
                score += isCritical(f, x, y);
            } else {
                ++otherfields;
            }
        }
    }
     // endangered cells are dangerous...
    score -= (countEndangered(f, p) << 1);
    // ... unless they belong to the other player
    score += countEndangered(f, otherplayer);
    
    // REALLY reward if no cells are left to the other guy
    if(otherfields == 0) {
        score += 1000;
    }
    
    return score;
}


int thinkAI(char field[SIZEX][SIZEY]) {
    char fieldAI[SIZEX][SIZEY];
    unsigned char x,y,owner;
    signed int tmp,score;
    unsigned int result;

    // compute the field score for the opposing player
    score = -32000;
    for(x = 0; x < SIZEX; ++x) {
        for(y = 0; y < SIZEY; ++y) {
            owner = getOwner(field, x, y);
            if(owner == PLAYERAI || owner == 0) {
                // we can use this cell
                memcpy(fieldAI, field, sizeof fieldAI); // create working copy
                tmp = 0;
                
                // it makes little sense to add atoms to endangered cells
                // unless they can start a chain reaction
                if(computeDanger(fieldAI, PLAYERAI, x, y) > 0 && isCritical(fieldAI, x, y) == 0) {
                    tmp -= 10;
                }

                // let the reaction run
                putAtom(fieldAI, PLAYERAI, x, y, 0);
                react(fieldAI, 0);
                
                // evaluate the resulting field constellation
                tmp += evaluateField(fieldAI, PLAYERAI);

                if(tmp > score || (tmp == score && (get_prng_value() & 0x01))) {
                    score = tmp;
                    result = (x << 8) | y;
                }
            }
        }
    }
    
    return result;
}


// --------------------
// game logic
// --------------------


char checkWinner(char f[SIZEX][SIZEY]) {
    char p1,p2,winner;
    winner = 0;
    p1 = getOwnerCount(f, 1);
    p2 = getOwnerCount(f, 2);

    if(playerplayed[1] && !p1) {
        winner = 2;
    } else if(playerplayed[2] && !p2) {
        winner = 1;
    }
    return winner;
}


void gameloop() {
    char field[SIZEX][SIZEY];
    signed char posx,posy; // signed for simple detection of underflow
    int move = 1;

    clearField(field);

    char player = 1;
      playerplayed[1] = 0;
    playerplayed[2] = 0;

    char winner = 0;

    printf(ANSI_CLEAR_SCREEN);
    while(!winner) {
        int playermove = -1;
        while(playermove < 0) {
            drawField(field, 0);
            if(player == 1 || !ki) {
                // puny human
                playermove = readPlayerMove(field, player);
            } else {
                // mighty computer
                playermove = thinkAI(field);
            }
        }
        posx = (char)(playermove >> 8);
        posy = (char)(playermove & 0xFF);

        // execute move
        putAtom(field, player, posx, posy, 0);
        playerplayed[player] = 1;
        move++;
        react(field, 1);
        
        // check for winner
        winner = checkWinner(field);
        
        if(!winner) {
            player = (player == 1) ? 2 : 1;
        }
    }

    drawField(field, 1);
    printf("Player %d won in %d moves!\n\r", player, move);
    char buf[2];
    read_string(buf, sizeof(buf), 0);
}

void gamemenu() {
    printf(ANSI_CLEAR_SCREEN);
    printf(ANSI_HOME);
    printf("=== CHAIN REACTION ===\n\n\r");
    printf("Players place tokens in turn. Once the number of tokens in a field reaches the number of horizontal and vertical neighbours, the field explodes. ");
    printf("Upon explosion tokens are redistributed into neighbouring fields, which are now owned by the owner of the exploding field.\n\n\r");
    printf(ANSI_COLOR_YELLOW);
    printf("Newly aquired fields may in turn explode, possibly causing a chain reaction.\n\n\r");
    printf(ANSI_COLOR_RESET);
    printf("A player wins if no fields are left to the other player.\n\n\r");
    printf("Enter number of players (1 or 2): ");
    char buf[2];
    read_string(buf, sizeof(buf), 1);
    int players = parse_int(buf);
    ki = players == 1 ? 1 : 0;
}

// -------------
// entry point
// -------------

int main(void) {
    while(1) {
        gamemenu();
        gameloop();
    }
}
