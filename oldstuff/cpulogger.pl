#!/usr/bin/perl
#

use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );

getopts('hu:l:vVF');

if( defined($opt_h) ) {
  print "usage:  cpulogger [opts] &\n",
   "  -u updatefreq     update the data every N seconds\n",
   "  -l lognum         log number (syslog LOCAL) for logging\n",
   "  -F                keep in foreground (don't daemonize)\n",
   "  -v                verbose\n",
   "  -V                really verbose\n";
  exit;
}

if( not defined($opt_F) ) {
   $pid = fork();
   if( $pid != 0 ) {
     # parent, should exit and return 0 error status
     $SIG{CHLD} = 'IGNORE';
     exit( 0 );
   }

   # from here on down, this is the child only
   chdir( '/' );
   setsid();
   open( STDIN,  "</dev/null" );
   open( STDOUT, ">/dev/null" );
   open( STDERR, ">&STDOUT" );
}

# turn off the signal handlers for now
$SIG{USR1} = 'IGNORE';
$SIG{USR2} = 'IGNORE';
$SIG{INT}  = 'IGNORE';

# since we use the ALARM signal to timeout of ping commands, we may
# end up with children that are waiting for ping to end, so make sure
# that we reap them when they are done
$SIG{CHLD} = 'IGNORE';

# ignore "Broken Pipe" signals so it doesn't crash the program
$SIG{PIPE} = 'IGNORE';

# check out the command line args
if( defined($opt_u) ) {
   $heartbeat = $opt_u;
} else {
   $heartbeat = 60*15;
}
if( defined($opt_l) ) {
   $loglocal = "local$opt_l";
} else {
   $loglocal = 'local4';
}
$verbose = 0;
if( defined($opt_v) ) {
   $verbose++
}
if( defined($opt_V) ) {
   $verbose += 10;
}

# start up system logs
#setlogsock( 'unix' );
openlog( 'cpulogger', 'ndelay,pid', $loglocal );
syslog( "info", "cpulogger starting, pid = $$" );

open( PP, '/proc/loadavg' );

if( $verbose ) {
   print "Entering main loop...\n";
}
while( 1 ) {
   seek( PP, 0, 0 );
   $_ = <PP>;
   ($x,$y,$z,$xtra) = split( /\s+/, $_ );
   $text = "load1=$x  load5=$y  load15=$z";
   if( $verbose > 10 ) {
      print "text = [$text]\n";
   }

   # log the memory/cpu usage numbers
   syslog( 'notice', $text );

   # turn on the signal handlers
   $SIG{USR1} = "handler1";
   $SIG{USR2} = "handler2";
   $SIG{INT}  = "handler3";

   sleep( $heartbeat );

   # turn off the signal handlers
   $SIG{USR1} = "IGNORE";
   $SIG{USR2} = "IGNORE";
   $SIG{INT}  = "IGNORE";
} # end-while

exit;

# *********************************************************************

sub handler1 {
   # do nothing on SIGUSR1
   # : however, this will wake up the
   #   process and start a new set of pings
}

sub handler2 {
   local $SIG{USR1} = "IGNORE";
   local $SIG{USR2} = "IGNORE";
   local $SIG{INT}  = "IGNORE";
}

sub handler3 {
   local $SIG{USR1} = "IGNORE";
   local $SIG{USR2} = "IGNORE";
   local $SIG{INT}  = "IGNORE";
   exit;
}


