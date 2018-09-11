#include "libspu32.h"
#include "../../asm/msr.h"
#include "../../asm/devices.h"

int read_msr_status() {
	int status = 0;
	asm("csrrw %[result], 0xFC0, zero" : [result] "=r" (status) );
	return status;
}

int write_msr_status(int status) {
	int oldstatus = 0;
	asm("csrrw %[result], 0x7C0, %[value]" : [result] "=r" (oldstatus) : [value] "r" (status) );
	return oldstatus;
}

int read_msr_cause() {
	int cause = 0;
	asm("csrrw %[result], 0xFC1, zero" : [result] "=r" (cause) );
	return cause;
}

int write_msr_cause(int cause) {
	int oldcause = 0;
	asm("csrrw %[result], 0x7C1, %[value]" : [result] "=r" (oldcause) : [value] "r" (cause) );
	return oldcause;
}

int read_msr_epc() {
	int epc = 0;
	asm("csrrw %[result], 0xFC2, zero" : [result] "=r" (epc) );
	return epc;
}

int write_msr_epc(int epc) {
	int oldepc = 0;
	asm("csrrw %[result], 0x7C2, %[value]" : [result] "=r" (oldepc) : [value] "r" (epc) );
	return oldepc;
}

int read_msr_evect() {
	int exception_vector = 0;
	asm("csrrw %[result], 0xFC3, zero" : [result] "=r" (exception_vector) );
	return exception_vector;
}

int write_msr_evect(int vec) {
	int oldvec = 0;
	asm("csrrw %[result], 0x7C3, %[value]" : [result] "=r" (oldvec) : [value] "r" (vec) );
	return oldvec;
}

int get_interrupt_enabled() {
    int status = read_msr_status();
    return status & 0x00000001;
}

void enable_interrupt() {
    int status = read_msr_status();
    status |= 0x00000001;
    write_msr_status(status);
}

void disable_interrupt() {
    int status = read_msr_status();
    status &= 0xFFFFFFFE;
    write_msr_status(status);
}

int get_interrupt_pending() {
    int status = read_msr_status();
    return status & 0x00000004;
}

int get_milli_time() {
	volatile int* dev = (int*)DEV_TIMER;
	return *dev;
}

void request_milli_time_interrupt(int timeoffset) {
	volatile int* dev = (int*)DEV_TIMER;
	int now = *dev;
	now += timeoffset;
	dev = (int*)DEV_TIMER_INTERRUPT;
	*dev = now;
}

void ack_milli_time_interrupt() {
	volatile char* dev = (char*)DEV_TIMER_INTERRUPT;
	char val = *dev;
}

char get_leds_value() {
	volatile char* dev = (char*)DEV_LED;
	return *dev;
}

void set_leds_value(char value) {
	volatile char* dev = (char*)DEV_LED;
	*dev = value;
}

int get_prng_value() {
	volatile int* dev = (int*)DEV_PRNG;
	return *dev;
}

void set_prng_seed(int seed) {
	volatile int* dev = (int*)DEV_PRNG;
	*dev = seed;
}