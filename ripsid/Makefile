CC=gcc
PROFILE=
CFLAGS=-Wall -std=c99 -O3 -DNDEBUG ${PROFILE}
LDFLAGS=-lm ${PROFILE}

all:		ripsidBRK

.PHONY:		all install clean

ripsidBRK:	ripsid.o
		gcc -o $@ $^ ${LDFLAGS}

clean:
		rm -rf *.o

install:	all
		mkdir -p /usr/local/bin
		cp ripsidBRK /usr/local/bin/
