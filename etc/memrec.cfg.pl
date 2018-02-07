# config file for memrec
# (perl syntax)

our $heartbeat   = 30;  # num seconds
our $outfile     = 'logfile.txt';
our @objs;

use procstat;
#use netinfo;
#use diskstats;

push( @objs, procstat->new() );
#push( @objs, netinfo->new() );
#push( @objs, diskstats->new() );
