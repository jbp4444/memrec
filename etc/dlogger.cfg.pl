# config file for dlogger
# (perl syntax)

our $heartbeat   = 60*60*4;  # num seconds for inner loop (every 4 hours)
our $loglocal    = 'local4';
#our $logname     = 'dlogger.pl';
#our $loghost     = 'bdgpu-n04.oit.duke.edu';
#our $logport     = 514;
#our $verbose     = 0;
#our $linesz      = 5;
#our $showxid     = 1;
#our $showkeys    = 1;
our $output      = 'syslog';
#our $outfile     = 'logfile.txt';
our @objs;


# what modules do you need?
use cpuinfo;
use linpack;
use gpuinfo;
use ipmiinfo;
use opsys;
use ifconfig;
#use txtfile;

# to config a module, use its prep(key,val) function
# linpack->prep( 'linpack_1', '/path/to/linpack; and_args' );
# linpack->prep( 'linpack_N', '/path/to/linpack; and_args' );

# modules to poll
push( @objs, cpuinfo->new() );
push( @objs, linpack->new() );
push( @objs, gpuinfo->new() );
push( @objs, ipmiinfo->new() );
push( @objs, opsys->new() );
push( @objs, ifconfig->new() );

1;
