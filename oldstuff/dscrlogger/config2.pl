# config file for dscrlogger2
# (perl syntax)

use netinfo10;
use loadavg;

our $logname = 'dscrlogger2';
our $heartbeat = 2;  # num. seconds for "inner loop"
our $inner2outer = 10;   # num inner loops per outer

# modules to poll less often (outer loop)
push( @objs_out, loadavg->new() );

# modules to poll more often (inner loop)
push( @objs_in, netinfo10->new() );

1;
