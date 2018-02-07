
CC = gcc
CFLAGS = 
LFLAGS = 

all: turbostat dump_tstat
	@echo __DONE__
clean:
	-rm *.o turbostat dump_tstat

turbostat: turbostat.o
	$(CC) $(LFLAGS) -o $@ $<
dump_tstat: dump_tstat.o
	$(CC) $(LFLAGS) -o $@ $<

.c.o:
	$(CC) $(CFLAGS) -o $@ -c $<
