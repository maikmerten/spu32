CC=cc
CFLAGS=-ggdb -fPIC -O2
LDFLAGS=


all: 
	$(CC) $(CFLAGS) -o filesrv_client filesrv_shared.c filesrv_client.c

clean:
	rm -rf filesrv_client *.o *.elf *.bin
