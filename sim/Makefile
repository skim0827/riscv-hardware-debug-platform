CC = gcc 
CFLAGS = -Wall -Wextra -Iinclude -O2

SRC = src/main.c src/execute.c src/memory.c src/trace.c
OBJ = $(SRC:.c =.0)

all : sim

sim : $(SRC)
		$(CC) $(CFLAGS) $^ -o sim 

clean : 
		rm -f sim src/*.o 

.PHONY : all clean 