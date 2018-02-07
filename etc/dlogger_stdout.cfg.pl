# config file for dlogger
# (perl syntax)

our $heartbeat   = 60;  # num seconds for inner loop
#our $inner2outer = 10;  # num inner loops per outer
our $loglocal    = 'local4';
#our $logname     = 'dlogger.pl';
#our $verbose     = 0;
#our $linesz      = 5;
our $output      = 'stdout';
#our $outfile     = 'logfile.txt';
our @objs;


# what modules do you need?
use df;
use ping;
use netinfo;
use diskstats;
use loadavg;
use procstat;
use meminfo;
use power;
use sgeshep;
use nfscli;
use turbostat;

use nvidiagpu;
use nvgpuload;

# to config a module, use its prep(key,val) function
#ping::prep( 'ping_cmd', '/bin/ping' );

# modules to poll less often (outer loop)
push( @objs, netinfo->new() );
push( @objs, df->new( 'tmp_free', '/tmp' ) );
push( @objs, df->new( 'var_free', '/var' ) );
push( @objs, df->new( 'scr_free', '/scratch' ) );
# pings go to monitor-02 on internal network
push( @objs, ping->new( '152.3.15.145' ) );
push( @objs, diskstats->new() );
push( @objs, loadavg->new() );
push( @objs, procstat->new() );
push( @objs, meminfo->new() );
push( @objs, power->new() );
push( @objs, sgeshep->new() );
push( @objs, nfscli->new() );
push( @objs, turbostat->new() );

push( @objs, nvidiagpu->new() );
push( @objs, nvgpuload->new() );

1;
