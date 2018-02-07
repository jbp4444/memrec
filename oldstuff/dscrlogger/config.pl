# config file for dscrlogger
# (perl syntax)

use df;
use ping;
use netinfo;
use diskstats;
#use sgeshep;
#use power;
use loadavg;
use procstat;
use meminfo;
use ifconfig;
use etcduke;
use cpuinfo;

our $logname = 'dscrlogger';
our $heartbeat = 10*60;  # num. seconds

push( @objs, netinfo->new() );
push( @objs, df->new( 'tmp_free', '/tmp' ) );
push( @objs, ping->new( '152.3.15.136', '/bin/ping' ) );
push( @objs, diskstats->new() );
#push( @objs, sgeshep->new() );
#push( @objs, power->new() );
push( @objs, loadavg->new() );
push( @objs, procstat->new() );
push( @objs, meminfo->new() );
push( @objs, cpuinfo->new() );
push( @objs, etcduke->new() );
push( @objs, ifconfig->new() );

1;
