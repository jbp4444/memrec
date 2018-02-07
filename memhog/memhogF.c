#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <sys/types.h>
#include <unistd.h>

int mem_used( void ) {
	FILE* fp;
	pid_t self;
	char procfile[128];
	char buffer[1024];
	static int count = 0;

	self = getpid();
	sprintf( procfile, "/proc/%i/status", self );
	fp = fopen( procfile, "r" );
	if( fp == NULL ) {
		return( -1 );
	}

	printf(" count=%i\n",count);
	count++;

	fgets( buffer, 1024, fp );
	while( ! feof(fp) ) {
		if( (buffer[0]=='V') && (buffer[1]=='m') ) {
			printf("  %s",buffer);
		}
		fgets( buffer, 1024, fp );
	}

	fclose( fp );

	return( 0 );
}

#ifdef MALLOC_STATS
int mem_used( void ) {
	int mem = 0;
	malloc_statistics_t mstat;
	static malloc_statistics_t oldstat = {0,0,0,0};

	malloc_zone_statistics( NULL, &mstat );

	printf("malloc_zone_statistics:\n");
	printf("   blocks_in_use   = %u\n",mstat.blocks_in_use);
	printf("   size_in_use     = %lu\n",mstat.size_in_use);
	printf("   max_size_in_use = %lu\n",mstat.max_size_in_use);
	printf("   size_allocated  = %lu\n",mstat.size_allocated);

	printf("diff malloc_zone_statistics:\n");
	printf("   blocks_in_use   = %u\n",mstat.blocks_in_use-oldstat.blocks_in_use);
	printf("   size_in_use     = %lu\n",mstat.size_in_use-oldstat.size_in_use);
	printf("   max_size_in_use = %lu\n",mstat.max_size_in_use-oldstat.max_size_in_use);
	printf("   size_allocated  = %lu\n",mstat.size_allocated-oldstat.size_allocated);

	oldstat = mstat;

	return( mem );
}
#endif

int main( int argc, char** argv ) {
	size_t sz = 1000;
	size_t spk = 0;
	int num_forks = 1;
	int delay[3] = {1,1,1};
	int i,j;
	char* buffer = NULL;
	char* spike = NULL;
	pid_t pid;

	for(i=0;i<argc;i++) {
		if( argv[i][0] == '-' ) {
			switch( argv[i][1] ) {
			  case 'm':
				sz = atoi( argv[i+1] );
				if( strchr(argv[i+1],'k') != NULL ) {
					sz *= 1000;
				} else if( strchr(argv[i+1],'K') != NULL ) {
					sz *= 1024;
				} else if( strchr(argv[i+1],'m') != NULL ) {
					sz *= 1000*1000;
				} else if( strchr(argv[i+1],'M') != NULL ) {
					sz *= 1024*1024;
				} else if( strchr(argv[i+1],'g') != NULL ) {
					sz *= 1000*1000*1000;
				} else if( strchr(argv[i+1],'G') != NULL ) {
					sz *= 1024*1024*1024;
				}
				i++;
				break;
			  case 's':
				spk = atoi( argv[i+1] );
				if( strchr(argv[i+1],'k') != NULL ) {
					spk *= 1000;
				} else if( strchr(argv[i+1],'K') != NULL ) {
					spk *= 1024;
				} else if( strchr(argv[i+1],'m') != NULL ) {
					spk *= 1000*1000;
				} else if( strchr(argv[i+1],'M') != NULL ) {
					spk *= 1024*1024;
				} else if( strchr(argv[i+1],'g') != NULL ) {
					spk *= 1000*1000*1000;
				} else if( strchr(argv[i+1],'G') != NULL ) {
					spk *= 1024*1024*1024;
				}
				i++;
				break;
			  case 'f':
				num_forks = atoi( argv[i+1] );
				i++;
				break;
			  case 'd':
				j = argv[i][2] - '0';
				delay[j] = atoi( argv[i+1] );
				if( strchr(argv[i+1],'m') != NULL ) {
					delay[j] *= 60;
				} else if( strchr(argv[i+1],'h') != NULL ) {
					delay[j] *= 60*60;
				}
				i++;
				break;
			}
		}
	}

	printf("Starting with %i bytes\n",sz);
	printf("  mem spike to %i bytes\n",spk);
	printf("  delays [%i %i %i]\n",delay[0],delay[1],delay[2]);
	printf("  num forks is %i\n",num_forks);
	fflush(stdout);

	for(i=0;i<num_forks;i++) {
		pid = fork();
		if( pid == 0 ) {
			/* child */
			printf("  child starting\n");
			break;
		} else {
			/* parent */
			printf("  parent starting\n");
		}
		fflush(stdout);
	}

	printf("Initial memory\n");
	mem_used();

	buffer = (char*)malloc( sz );
	if( buffer == NULL ) {
		printf("** Error: cannot alloc %i bytes (main)\n",sz);
		exit( -1 );
	}

	printf("Got main memory\n");
	mem_used();
	fflush( stdout );

	printf("   sleeping %i\n",delay[0]);
	sleep( delay[0] );

	spike = (char*)malloc( spk );
	if( spike == NULL ) {
		printf("** Error: cannot alloc %i bytes (spike)\n",spk);
		exit( -2 );
	}

	printf("Got spike memory\n");
	mem_used();
	fflush( stdout );

	printf("   sleeping %i\n",delay[1]);
	sleep( delay[1] );

	free( spike );

	printf("Freed spike\n");
	mem_used();
	fflush( stdout );

	printf("   sleeping %i\n",delay[2]);
	sleep( delay[2] );

	free( buffer );

	printf("Freed main memory\n");
	mem_used();
	printf("Done!\n");

	if( pid ) {
		waitpid( pid, NULL, NULL );
	}

	return( 0 );
}

