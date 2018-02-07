use etcduke;
use cpuinfo;

# for hourly scans of pseudo-static data
our $logname = 'hourly';
our $heartbeat = 60*60;  # num. seconds

push( @objs, cpuinfo->new() );
push( @objs, etcduke->new() );

1;
