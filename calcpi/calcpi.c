
// needed for some of the pthread_attr stuff
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>

int run_type = 0;
int Rpt = 100;  // outer repeat loop
int Dur = 100;  // duration (sec)
int Thr = 1;    // num threads
unsigned long int N = 100;    // inner loop
int Affin = 0;  // processor affinity?

int SpikeYN = 0;      // perform a thread-spike?
int SpikeDelay = 0;   // sec to delay before thread-spike
int SpikeThreads = 0; // how many threads during spike?
int SpikeDur = 0;     // duration of thread-spike (sec)

void* calcpi_int( void* p ) {
    double x,y,circrad2;
    unsigned long int i,incirc=0;
    unsigned int rseed;
    int tnum = *(int*)(p);

    if( Affin ) {
        /* Set affinity mask to include CPUs 0 to 7 */
        cpu_set_t cpuset;
        pthread_t tid;
        tid = pthread_self();
        CPU_ZERO( &cpuset );
        CPU_SET( tnum, &cpuset );
        pthread_setaffinity_np( tid, sizeof(cpu_set_t), &cpuset );
    }

    circrad2=1.0*RAND_MAX;
    circrad2*=circrad2;        // Define radius squared

    for(i=0;i<N;i++) {
        x=1.0*rand_r(&rseed);
        y=1.0*rand_r(&rseed);     // get rand. point and
        incirc += (x*x+y*y) < circrad2; // check if inside circle
    }

    if( p != NULL ) {
    	float* dp = (float*)p;
    	*dp = (4.0*(float)(incirc))/(float)(N);
    }

    return( NULL );
}

double calcpi( void ) {
	int t,e;
	pthread_t pid[128];
	float data[128];

	for(t=0;t<Thr;t++) {
		data[t] = t;
		e = pthread_create( &pid[t], NULL, calcpi_int, &data[t] );
		if( e ) {
			printf("thread-%i threw error-%i\n",t,e);
		}
	}
	for(t=0;t<Thr;t++) {
		pthread_join( pid[t], NULL );
	}
	return( data[0] );
}

void spike_int( void ) {
	int t,e;
	pthread_t pid[128];
	float data[128];

	// assume SpikeThreads is TOTAL number of threads desired,
	// ... we already have Thr started
	for(t=Thr;t<SpikeThreads;t++) {
		data[t] = t;
		e = pthread_create( &pid[t], NULL, calcpi_int, &data[t] );
		if( e ) {
			printf("thread-%i threw error=%i\n",t,e);
		}
	}
	for(t=Thr;t<SpikeThreads;t++) {
		pthread_join( pid[t], NULL );
	}

    return;
}

void* spike( void* p ) {
	time_t t0,t1;

	printf("thread-spike: waiting\n");
	sleep( SpikeDelay );
	printf("thread-spike: firing %i\n",SpikeThreads);

	t0 = time(NULL);
	t1 = t0;
	while( (t1-t0) < SpikeDur ) {
		spike_int();
		t1 = time(NULL);
	}

	printf("thread-spike: done\n");

	return( NULL );
}

void show_help( void ) {
	printf("usage:  calcpi [-d sec | -r rpt] [opts]\n");
	printf("  -d N     run for N seconds\n");
	printf("  -r N     run N times\n");
	printf("  -n N     run N iterations per test\n");
	printf("  -t N     run with N threads\n");
	printf("  -a       use processor-affinity\n");
	printf("  -st      thread-spike: num threads\n");
	printf("  -sw      thread-spike: wait/delay to spike (sec)\n");
	printf("  -sd      thread-spike: duration of spike (sec)\n");
	return;
}

void parse_cmdline( int ac, char** av ) {
	int i;

	for(i=1;i<ac;i++) {
		if( av[i][0] == '-' ) {
			switch( av[i][1] ) {
			case 'n':
				N = (unsigned long int)( atof(av[i+1]) );
				i++;
				break;
			case 't':
				Thr = atoi(av[i+1]);
				i++;
				break;
			case 'r':
				Rpt = atoi(av[i+1]);
				i++;
				run_type = 1;
				break;
			case 'd':
				Dur = atoi(av[i+1]);
				i++;
				run_type = 2;
				break;
			case 'a':
				Affin ^= 1;
				break;
			case 's':
				SpikeYN = 1;
				switch( av[i][2] ) {
				case 't':
					SpikeThreads = atoi( av[i+1] );
					i++;
					break;
				case 'w':
					SpikeDelay = atoi( av[i+1] );
					i++;
					break;
				case 'd':
					SpikeDur = atoi( av[i+1] );
					i++;
					break;
				}
				break;
			case 'h':
				show_help();
				exit( 0 );
				break;
			}
		} else {
			// not a '-x' style argument, maybe a filename?
		}
	}

	return;
}

int main(int argc, char *argv[]) {
	double pi;

	parse_cmdline( argc, argv );
	printf("runtype=%i thr=%i rpt=%i dur=%i aff=%i\n",run_type,Thr,Rpt,Dur,Affin);
	if( SpikeYN ) {
		printf("  thread-spike: thr=%i dur=%i delay=%i\n",SpikeThreads,SpikeDur,SpikeDelay);
	}

	if( SpikeYN ) {
		pthread_t spike_pid;
		pthread_create( &spike_pid, NULL, spike, NULL );
	}

	if( run_type == 1 ) {
		int i;
		for(i=0;i<Rpt;i++) {
			pi = calcpi();
		}
		printf("pi = %.9lf\n",pi);
	} else if( run_type == 2 ) {
		time_t t0,t1;
		t0 = time(NULL);
		t1 = t0;
		while( (t1-t0) < Dur ) {
			pi = calcpi();
			t1 = time(NULL);
		}
		printf("pi = %.9lf\n",pi);
	} else {
		show_help();
	}

    return( 0 );
}

