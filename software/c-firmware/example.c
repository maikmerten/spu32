#include <libtinyc.h>
#include <libspu32.h>

void isr()__attribute((interrupt));
void isr() {
	printf("isr\r\n");
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
		printf("old value of MSR_EVECT: %d\r\n", read_msr_evect());
		int oldval = write_msr_evect(parsed);
		printf("setting MSR_EVECT to %d, old value was %d\r\n", parsed, oldval);
		printf("interrupt enabled? %d\r\n", get_interrupt_enabled());
		enable_interrupt();
		printf("interrupt enabled? %d\r\n", get_interrupt_enabled());
		disable_interrupt();
		printf("interrupt enabled? %d\r\n", get_interrupt_enabled());


		printf("Location of ISR is %d\r\n", isr);

		printf("strcmp('Hello', name) is %d\n\r", strcmp("Hello", name));

		printf("This is message %d\r\n\r\n", i);

		i++;
	}

	return 0;
}

