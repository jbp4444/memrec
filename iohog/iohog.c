#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include <sys/types.h>
#include <unistd.h>

int run_type = 0;
size_t NumRec = 100;
size_t RecSize = 1000;
int Delay[3] = {1,1,1};
char* Fname = "default.dat";
int DoSync = 0;

size_t convert_kb( char* s ) {
	size_t v;
	v = atoi( s );
	if( strchr(s,'k') != NULL ) {
		v *= 1000;
	} else if( strchr(s,'K') != NULL ) {
		v *= 1024;
	} else if( strchr(s,'m') != NULL ) {
		v *= 1000*1000;
	} else if( strchr(s,'M') != NULL ) {
		v *= 1024*1024;
	} else if( strchr(s,'g') != NULL ) {
		v *= 1000*1000*1000;
	} else if( strchr(s,'G') != NULL ) {
		v *= 1024*1024*1024;
	}
	return( v );
}

void parse_cmdline( int ac, char** av ) {
	int i,j;

	for(i=0;i<ac;i++) {
		if( av[i][0] == '-' ) {
			switch( av[i][1] ) {
			  case 'r':
				RecSize = convert_kb( av[i+1] );
				i++;
				break;
			  case 'n':
				NumRec = convert_kb( av[i+1] );
				i++;
				break;
			  case 'd':
				j = av[i][2] - '0';
				Delay[j] = atoi( av[i+1] );
				if( strchr(av[i+1],'m') != NULL ) {
					Delay[j] *= 60;
				} else if( strchr(av[i+1],'h') != NULL ) {
					Delay[j] *= 60*60;
				}
				i++;
				break;
			  case 'f':
				Fname = av[i+1];
				i++;
				break;
			  case 'O':
				  run_type = 1;
				  break;
			  case 'S':
				  DoSync = 1;
				  break;
			  case 'F':
				  DoSync = 2;
				  break;
			}
		}
	}

}

int main( int argc, char** argv ) {
	int i,j;
	char* buffer = NULL;
	FILE* fp;

	parse_cmdline( argc, argv );

	printf("Writing %i records of %i bytes per record\n",NumRec,RecSize);
	printf("  filename is [%s]\n",Fname);
	printf("  Delays [%i %i %i]\n",Delay[0],Delay[1],Delay[2]);
	printf("  Sync [%i]\n",DoSync);
	fflush(stdout);

	fp = fopen( Fname, "w" );

	buffer = (char*)malloc( RecSize );
	if( buffer == NULL ) {
		printf("** Error: cannot alloc %i bytes (main)\n",RecSize);
		exit( -1 );
	}
	for(i=0;i<(RecSize-1);i++) {
		buffer[i] = 'x';
	}
	buffer[i] = 0;

	printf("Got buffer memory\n");
	fflush( stdout );

	printf("   sleeping %i\n",Delay[0]);
	sleep( Delay[0] );

	for(i=0;i<NumRec;i++) {
		fwrite( buffer, RecSize, 1, fp );
		if( run_type == 1 ) {
			fseek( fp, 0L, SEEK_SET );
		}
		printf("Wrote rec %i\n",i);
		if( DoSync == 1 ) {
			fsync( fileno(fp) );
		} else if( DoSync == 2 ) {
			fflush( fp );
		}
		fflush( stdout );
		sleep( Delay[1] );
	}

	free( buffer );
	fclose( fp );

	printf("Freed buffer memory\n");
	printf("Done!\n");

	return( 0 );
}

