CC ?= cc
CFLAGS ?= -std=c11 -Wall -Wextra -Wpedantic -O2

.PHONY: all test clean

all: test_progress_meter

test_progress_meter: progress_meter.o test_progress_meter.o
	$(CC) $(CFLAGS) $^ -lm -o $@

progress_meter.o: progress_meter.c progress_meter.h
	$(CC) $(CFLAGS) -c progress_meter.c -o $@

test_progress_meter.o: test_progress_meter.c progress_meter.h
	$(CC) $(CFLAGS) -c test_progress_meter.c -o $@

test: test_progress_meter
	./test_progress_meter

clean:
	rm -f progress_meter.o test_progress_meter.o test_progress_meter
