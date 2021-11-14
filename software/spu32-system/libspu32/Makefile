include ../../Makefile.vars

CC=${RV_GCC}
CFLAGS=-static -march=rv32im -mno-div -mabi=ilp32 -nostdlib -Os -fno-builtin-printf -fPIC -fdata-sections -ffunction-sections

AR=${RV_AR}
ARFLAGS=rs

DUMP=${RV_OBJDUMP}

.PHONY: clean dump

all: libspu32.a

dump: libspu32.o
	$(DUMP) -d $<


%.o: %.c
	$(CC) $(CFLAGS) -c $<


%.a: %.o
	$(AR) $(ARFLAGS) $@ $<



clean:
	-rm *.o *.a
