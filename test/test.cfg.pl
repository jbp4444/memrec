# config file for dlogger
# (perl syntax)

our $heartbeat   = 10;  # num seconds for inner loop
our $loglocal    = 'local4';
#our $logname     = 'dlogger.pl';
#our $loghost     = 'bdgpu-n04.oit.duke.edu';
#our $logport     = 514;
#our $verbose     = 0;
#our $linesz      = 5;
our $output      = 'stdout';
#our $outfile     = 'logfile.txt';
our @objs;


# what modules do you need?
use dmesg;

# to config a module, use its prep(key,val) function
dmesg->prep( 'watch', 'dummy line' );

# modules to poll
push( @objs, dmesg->new() );

1;
