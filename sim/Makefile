CC = gcc 
CFLAGS = -Wall -Wextra -Iinclude -O2

SRC_BASELINE = src/baseline/main.c \
               src/baseline/execute.c \
               src/baseline/memory.c \
               src/baseline/trace.c

SRC_SPACE    = src/space/main_space.c \
               src/space/execute_space.c \
               src/space/memory_space.c \
               src/space/fault_inject.c \
               src/space/trace.c





all: baseline space

baseline: $(SRC_BASELINE)
	$(CC) $(CFLAGS) $^ -o sim_baseline

space: $(SRC_SPACE)
	$(CC) $(CFLAGS) $^ -o sim_space

clean:
	rm -f sim_baseline sim_space

.PHONY: all baseline space clean