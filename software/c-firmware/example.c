#include <libtinyc.h>

int main() {

	int i = 0;
	while(1) {
		printf("Hi there!\r\n");
		printf("This is message %d\r\n", i);

		i++;
	}

	return 0;
}