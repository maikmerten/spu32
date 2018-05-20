#include <libtinyc.h>

int main() {

	char name[16];

	int i = 0;
	while(1) {
		printf("Your name: ");
		fgets(name, sizeof name, 0);
		printf("\r\n");

		printf("Hi %s!\r\n", name);
		printf("This is message %d\r\n\r\n", i);

		i++;
	}

	return 0;
}