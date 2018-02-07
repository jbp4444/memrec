use ifconfig;
use etcduke;
use cpuinfo;

our $logname = 'once';

push( @objs, cpuinfo->new() );
push( @objs, etcduke->new() );
push( @objs, ifconfig->new() );

1;
