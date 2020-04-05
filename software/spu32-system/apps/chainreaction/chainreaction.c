#ifndef STDLIB
#include <libtinyc.h>
#include <libspu32.h>
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
    printf("\b\b\b   \b\b\b"); // move cursor back and remove input

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
			} else if(owner == otherplayer) {
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

int gamemenu() {
	printf(ANSI_CLEAR_SCREEN);
	printf(ANSI_HOME);
	printf("=== CHAIN REACTION ===\n\n\r");
	printf("Players place tokens in turn. Once the number of tokens in a field reaches the number of horizontal and vertical neighbours, the field explodes. ");
	printf("Upon explosion tokens are redistributed into neighbouring fields, which are now owned by the owner of the exploding field.\n\n\r");
	printf(ANSI_COLOR_YELLOW);
	printf("Aquired fields may in turn explode, possibly causing a chain reaction.\n\n\r");
	printf(ANSI_COLOR_RESET);
	printf("A player wins if no fields are left to the other player.\n\n\r");
	printf("Number of players (1 or 2), 0 to exit: ");
	char buf[2];
	read_string(buf, sizeof(buf), 1);
	int players = parse_int(buf);
	if(players == 0) {
		return 1;
	}

	ki = players == 1 ? 1 : 0;
	return 0;
}

// -------------
// entry point
// -------------

int main(void) {
    while(1) {
		int exit = gamemenu();
		if(exit) {
			break;
		}
        gameloop();
    }
	return 0;
}
