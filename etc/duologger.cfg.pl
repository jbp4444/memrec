# config file for dlogger
# (perl syntax)

our $heartbeat   = 60;  # num seconds for inner loop
our $inner2outer = 10;  # num inner loops per outer
our $loglocal    = 'local4';
our $logname     = 'duologger.pl';
#our $loghost     = 'bdgpu-n04.oit.duke.edu';
#our $logport     = 514;
#our $verbose     = 0;
#our $linesz      = 5;
#our $showxid     = 1;
#our $showkeys    = 1;
our $output      = 'syslog';
#our $outfile     = 'logfile.txt';


# what modules do you need?
use df;
use ping;
use netinfo10;
use diskstats;
use loadavg;
use procstat;
use meminfo;
use power;
use sgeshep;
use nfscli;
use turbostat;

# to config a module, use its prep(key,val) function
ping->prep( 'ping_ip', '10.184.3.10');
turbostat->prep( 'dump_cmd', '/home/scsc/jbp1/seq/memrec/src/dump_tstat' );

# modules to poll more often (inner loop)
push( @objs_in, netinfo10->new() );

# modules to poll less often (outer loop)
push( @objs_out, df->new( 'tmp_free', '/tmp' ) );
push( @objs_out, df->new( 'var_free', '/var' ) );
push( @objs_out, df->new( 'scr_free', '/scratch' ) );
# pings go to monitor-02 on internal network
push( @objs_out, ping->new() );
push( @objs_out, diskstats->new() );
push( @objs_out, loadavg->new() );
push( @objs_out, procstat->new() );
push( @objs_out, meminfo->new() );
push( @objs_out, power->new() );
push( @objs_out, sgeshep->new() );
push( @objs_out, nfscli->new() );
push( @objs_out, turbostat->new() );

1;
