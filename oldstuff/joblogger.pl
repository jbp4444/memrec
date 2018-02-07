#!/usr/bin/perl
#

use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );

getopts('hu:l:J:vVF');

if( defined($opt_h) ) {
  print "usage: $0 [opts] &\n",
   "  -u updatefreq     update the data every N seconds\n",
   "  -l lognum         log number (syslog LOCAL) for logging\n",
   "  -J jobid          start at jobid (default=1)\n",
   "  -F                keep in foreground (don't daemonize)\n",
   "  -v                verbose\n",
   "  -V                really verbose\n";
  exit;
}

@users = ( 'aaa', 'bbb', 'ccc', 'ddd' );
%usr_to_grp = (
  'aaa' => 'aaa1,aaa2,aaa3',
  'bbb' => 'bbb1',
  'ccc' => 'ccc1,ccc2,ccc3,ccc4',
  'ddd' => 'ddd1,ddd2,ddd3,ddd4'
);

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
if( defined($opt_J) ) {
   $jobid = $opt_J;
} else {
   $jobid = 1;
}
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
openlog( 'joblogger', 'ndelay,pid', $loglocal );
syslog( "info", "joblogger starting, pid = $$" );

if( $verbose ) {
   print "Entering main loop...\n";
}
while( 1 ) {
   # pick a user and group
   $u = int( scalar(@users)*rand() );
   if( $u < 0 ) {
      $u = 0;
   }
   if( $u >= scalar(@users) ) {
      $u = scalar(@users) - 1;
   }
   $uu = $users[$u];
   $ug = $usr_to_grp{$uu};
   @ugg = split( ',', $ug );
   $g = int( scalar(@ugg)*rand() );
   if( $g < 0 ) {
      $g = 0;
   }
   if( $g >= scalar(@ugg) ) {
      $g = scalar(@ugg) - 1;
   }
   $gg = $ugg[$g];

   # log the job submission
   $text = "jobid=$jobid user='$uu' group='$gg' JOBSUBMIT";
   syslog( 'notice', $text );

   sleep( rand() * 100 );

   # log the job start
   $text = "jobid=$jobid JOBSTART";
   syslog( 'notice', $text );

   sleep( rand() * 600 );

   # log the job end
   $text = "jobid=$jobid JOBFINISH";
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

   $jobid++;
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


