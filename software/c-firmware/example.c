#include <libtinyc.h>

void isr()__attribute((interrupt));
void isr() {
	printf("isr\r\n");
}

inline int get_msr_evect() {
	int exception_vector = 0;
	asm("csrrw %[result], 0xFC3, zero" : [result] "=r" (exception_vector) );
	return exception_vector;
}

inline int set_msr_evect(int vec) {
	int oldvec = 0;
	asm("csrrw %[result], 0x7C3, %[value]" : [result] "=r" (oldvec) : [value] "r" (vec) );
	return oldvec;
}

int main() {

	char name[16];

	int i = 0;
	while(1) {
		printf("Your name: ");
		read_string(name, sizeof name, 1);
		printf("\r\n");

		int parsed = parse_int(name);

		printf("Hi %s!\r\n", name);
		printf("Your name has %d characters!\r\n", string_length(name));
		printf("Your name sloppily parsed as int: %d\r\n", parsed);
		printf("old value of MSR_EVECT: %d\r\n", get_msr_evect());
		int oldval = set_msr_evect(parsed);
		printf("setting MSR_EVECT to %d, old value was %d\r\n", parsed, oldval);


		printf("Location of ISR is %d\r\n", isr);
		printf("This is message %d\r\n\r\n", i);

		i++;
	}

	return 0;
}

