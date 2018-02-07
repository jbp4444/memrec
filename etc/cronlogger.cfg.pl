# config file for dlogger
# (perl syntax)

our $loglocal    = 'local4';
our $logname     = 'cronlogger.pl';
#our $verbose     = 0;
#our $linesz      = 5;
#our $showxid     = 1;
#our $showkeys    = 1;
our $output      = 'syslog';
#our $outfile     = 'logfile.txt';


# what modules do you need?
use ifconfig;
use etcduke;
use cpuinfo;
use linpack;
use opsys;
use txtfile;

push( @objs, cpuinfo->new() );
push( @objs, etcduke->new() );
push( @objs, ifconfig->new() );
push( @objs, linpack->new() );
push( @objs, opsys->new() );
push( @objs, txtfile->new('/etc/duke/qloadvals') );

1;
