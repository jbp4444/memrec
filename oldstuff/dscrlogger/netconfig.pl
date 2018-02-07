use const;
use snmpswitch;

our $logname = 'netlogger';
our $heartbeat = 10;  # num. seconds to poll device(s)
our $samples_for_max = 4;  # num. samples before output to syslog

push( @objs, snmpswitch->new( '10.10.1.143', 'public' ) );

1;
