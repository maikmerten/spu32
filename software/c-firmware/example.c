#include <libtinyc.h>

int main() {

	char name[16];

	int i = 0;
	while(1) {
		printf("Your name: ");
		read_string(name, sizeof name, 1);
		printf("\r\n");

		printf("Hi %s!\r\n", name);
		printf("Your name has %d characters!\r\n", string_length(name));
		printf("Your name sloppily parsed as int: %d\r\n", parse_int(name));
		printf("Your name sloppily parsed as long: %d\r\n", parse_long(name));
		printf("This is message %d\r\n\r\n", i);

		i++;
	}

	return 0;
}