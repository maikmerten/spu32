CC=cc
CFLAGS=-ggdb -fPIC -O2
LDFLAGS=


all: uploader.o
	$(CC) $(CFLAGS) -o uploader uploader.o

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -rf *.o *.elf *.bin
