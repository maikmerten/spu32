#include <libtinyc.h>
#include <libspu32.h>

int pass;

void error(char i) {
    set_leds_value(i);
    while(1) {}
}

/*
* First check: A naive way to compute prime numbers
*/

int isPrime(int candidate) {
    int test = (candidate/2)+1;
    while(--test > 1) {
        if((candidate / test) * test == candidate) {
            return 0;
        }
    }
    return 1;
}

int naivePrime(int* primes, int n) {
    int sum = 0;
    int last = 1;
    int idx = 0;
    while(idx < n) {
        int candidate = last + 1;

        while(!isPrime(candidate)) {
            candidate++;
        }

        sum += candidate;
        last = candidate;
        primes[idx++] = candidate;
    }

    return sum;
}

void checkPrime() {
    int prime1[100];

    int sum1 = naivePrime(prime1, sizeof(prime1)/sizeof(prime1[0]));
    int sum2 = 0;
    for(int idx = 0; idx < sizeof(prime1)/sizeof(prime1[0]); ++idx) {
        sum2 += prime1[idx];
    }

    if(sum1 != sum2 || sum1 != 24133) {
        printf("sum of first 100 prime numbers does not check out!\n\r");
        error(1);
    } else {
        printf("prime number test passed\n\r");
    }
}

/*
* Second check: Naive sorting algorithm
*/

void naiveSort(int* numbers, int n) {
    char finished = 1;
    int tmp = 0;

    do {
        finished = 1;
        for(int idx = 0; idx < (n-1); ++idx) {
            if(numbers[idx+1] < numbers[idx]) {
                finished = 0;
                tmp = numbers[idx];
                numbers[idx] = numbers[idx+1];
                numbers[idx+1] = tmp;
            }
        }

    } while(!finished);

}


void checkSort() {
    int numbers[100];

    // fill up array with 1 to 100... backwards
    for(int idx = 0; idx < 100; ++idx) {
        numbers[idx] = 100 - idx;
    }

    naiveSort(numbers, 100);

    // check sorting result
    char err = 0;
    for(int idx = 0; idx < 99; ++idx) {
        if(numbers[idx] > numbers[idx+1]) {
            err = 1;
            break;
        }
    }

    if(err) {
        printf("sorting test failed\n\r");
        error(2);
    } else {
        printf("sorting test passed\n\r");
    }

}

/*
* Third check: Fibonacci!
*/

int fib(n)  {
    if(n < 3) return 1;
    return fib(n-1) + fib(n-2);
}

void checkFib() {
    int n = fib(20);

    if(n != 6765) {
        printf("fibonacci test failed %d\n\r", n);
        error(3);
    } else {
        printf("fibonacci test passed\n\r");
    }
}

/*
* Fourth check: memcpy
*/

int checkMemcpy() {
    char buf1[337];
    char buf2[337];

    set_prng_seed(pass);

    for(int repeat = 0; repeat < 128; ++repeat) {
        // fill buf1 with random valuesö
        for(int i = 0; i < sizeof buf1; ++i) {
            buf1[i] = (char)(get_prng_value() & 0xFF);
        }
        // terminate "string"
        buf1[(sizeof buf1) - 1] = 0;

        // scrub buf2
        for(int i = 0; i < sizeof buf2; ++i) {
            buf2[i] = 0;
        }

        // copy contents of buf1 to buf2...
        memcpy(buf2, buf1, sizeof buf2);

        // ... and compare. buf1 and buf2 should match
        if(strcmp(buf1, buf2) != 0) {
            printf("memcpy/strcmp failed!\n\r");
            error(4);
        }
    }
    
    printf("memcpy/strcmp test passed\n\r");
}


int main() {
    pass = 0;


    while(1) {
        printf("\n\r=== Pass %d ===\n\r", pass);
        set_leds_value(pass);
        checkPrime();
        checkSort();
        checkFib();
        checkMemcpy();
        pass++;
    }

	
}

