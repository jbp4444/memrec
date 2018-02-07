# config file for dlogger
# (perl syntax)

our $heartbeat   = 60*15;  # num seconds for inner loop (every 15 min)
our $loglocal    = 'local4';
our $logname     = 'condorlogger.pl';
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
use condorinfo;

# to config a module, use its prep(key,val) function
# linpack->prep( 'linpack_1', '/path/to/linpack; and_args' );
# linpack->prep( 'linpack_N', '/path/to/linpack; and_args' );

# modules to poll
push( @objs, condorinfo->new() );

1;
