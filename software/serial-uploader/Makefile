CC=cc
CFLAGS=-ggdb -fPIC
LDFLAGS=


all: uploader.o
	$(CC) $(CFLAGS) -o uploader uploader.o

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -rf *.o *.elf *.bin
