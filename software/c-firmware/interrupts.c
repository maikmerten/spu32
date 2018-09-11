#include <libtinyc.h>
#include <libspu32.h>

void isr()__attribute((interrupt));
void isr() {
	ack_milli_time_interrupt();
	printf("isr! predictable random number: %d\r\n", get_prng_value());

	request_milli_time_interrupt(500);
}


int main() {

	set_prng_seed(1337);

	// set MSR_EVECT to interrupt service routine
	write_msr_evect(isr);
	// now we can process interrupts
	enable_interrupt();
	// request an interrupt in one second
	request_milli_time_interrupt(1000);


	while(1){
		int i = 0;
		while(i < 200 * 1000) {
			i++;
		}

		// disable interrupts temporarily to make sure the message is not garbled by isr output
		disable_interrupt();
		printf("message from main loop\r\n");
		enable_interrupt();


	}

	return 0;
}

