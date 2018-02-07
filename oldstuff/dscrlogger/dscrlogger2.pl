#!/usr/bin/perl
#
# (C) 2010-2011, John Pormann, Duke University
#      jbp1@duke.edu
#
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# RCSID $Id: dscrlogger2.pl 222 2011-08-17 14:11:33Z jbp $
#
# dscrlogger2.pl -- perl-based daemon/monitor/logger for the DSCR
#    with syslog functionality

# TODO:
# --> mount-point checker (maybe only needed hourly?)
# --> running process checker (hourly?)

#use strict;

use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );

use FindBin ();
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../modules";
use lib "$FindBin::Bin/../lib/modules";

# defaults
our $heartbeat   = 30;
our $inner2outer = 5;
our $loglocal    = 'local4';
our $logname     = 'dscrlogger2.pl';
our $verbose     = 0;
our $linesz      = 5;
our $output      = 'syslog';
our $outfile     = 'logfile.txt';
our $cfgfile     = "$FindBin::Bin/config2.pl";

#
# get command-line options
getopts('vVXhi:f:l:n:o:F:DS');
if( defined($opt_h) ) {
	print "usage:  $0 [opts]\n"
	  .   "   -i num       set num inner to outer iters (default=$inner2outer)\n"
	  .   "   -f file      set config file (default=$cfgfile)\n"
	  .   "   -o outtype   set output type (default=$output)\n"
	  .   "   -l localN    set syslog facility [*] (default=$loglocal)\n"
	  .   "   -n logname   set logger name [*] (default=$logname)\n"
	  .   "   -F filename  set output file name [**] (default=$outfile)\n"
	  .   "   -S           run a single data-collection cycle\n"
	  .   "   -D           don't daemonize, stay in foreground\n"
	  .   "   -v           verbose output\n"
	  .   "   -V           really verbose output\n"
	  .   "output type is one of {syslog,file,stdout}\n"
	  .   "[*] only required for output=='syslog'\n"
	  .   "[**] only required for output=='file'\n";
	exit( 1 );
}
if ( defined($opt_v) ) {
	$verbose++;
}
if ( defined($opt_V) ) {
	$verbose += 10;
}
if ( defined($opt_i) ) {
	$inner2outer = $opt_i + 0;
}
if ( defined($opt_f) ) {
	$cfgfile = $opt_f;
}
if ( defined($opt_l) ) {
	$loglocal = $opt_l;	
}
if ( defined($opt_n) ) {
	$logname = $opt_n;
}
if ( defined($opt_F) ) {
	$outfile = $opt_F;
}
if ( defined($opt_o) ) {
	$output = $opt_o;	
}
if( defined($opt_S) ) {
	# for single data collection cycle,
	# no need to daemonize
	$opt_D = 1;
}

#
# override with config file
our @objs_in  = ();
our @objs_out = ();
require $cfgfile;


#
# a little error-checking
if( $loglocal =~ m/^local[0-7]$/ ) {
	# ok .. looks like a valid identifier
} else {
	print "** Error: loglocal/-l must be local0 through local7\n";
	exit( -1 );
}

# make life easier later on ... (no string matching)
my $outtype;
if( $output =~ m/syslog/i ) {
	$outtype = 0;
} elsif( $output =~ m/file/i ) {
	$outtype = 1;
} elsif( $output =~ m/stdout/i ) {
	$outtype = 2;
	# cannot daemonize or we'll loose stdout
	$opt_D = 1;
} else {
	print "** Error: output/-o must be one of {syslog,file,stdout}\n";
	exit( -2 );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# Daemonize
if ( not defined($opt_D) ) {
	my $pid = fork();
	if ( $pid != 0 ) {

		# parent, should exit and return 0 error status
		$SIG{CHLD} = 'IGNORE';
		exit(0);
	}

	# from here on down, this is the child only
	chdir("$FindBin::Bin");
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

# start up the output system
if( $outtype == 0 ) {
	openlog( $logname, 'ndelay,pid', $loglocal );
	syslog( 'info', 'logging process starting' );
} elsif( $outtype == 1 ) {
	open( TXTLOG, ">$outfile" );
	print TXTLOG "logging process starting\n";
} elsif( $outtype == 2 ) {
	print "logging process starting\n";
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# main loop

my $tstamp = time();
my %data = ();
my ( $o, $k, $v, $txt, $n, $itr );

if ($verbose) {
	print "Entering main loop...\n";
}
while (1) {
	#
	# this loop does N-1 inner iterations
	# ... we'll handle the final inner-interation later
	for ( $itr = 1 ; $itr < $inner2outer ; $itr++ ) {
		$tstamp = time;
		%data                = ();
		$data{'tstamp'}      = $tstamp;
		foreach $o (@objs_in) {
			$o->getdata( \%data );
		}
		
		sleep($heartbeat);
	}

	#
	# last inner-iteration 
	# ... and also the outer-iteration
	$tstamp = time;
	%data                = ();
	$data{'tstamp'}      = $tstamp;
	foreach $o ( @objs_in, @objs_out) {
		$o->getdata( \%data );
	}

	$txt = "xid=$tstamp ";
	$n   = 0;
	while ( ( $k, $v ) = each %data ) {
		if ( $k eq 'tstamp' ) {
			next;
		}
		$txt .= "$k=$v ";

		$n++;
		if ( $n == $linesz ) {
			if( $outtype == 0 ) {
				syslog( 'notice', $txt );
			} elsif( $outtype == 1 ) {
				print TXTLOG $txt . "\n";
			} elsif( $outtype == 2 ) {
				print $txt . "\n";
			}
			$txt = "xid=$tstamp ";
			$n   = 0;
		}
	}
	if ( $n > 0 ) {
		if( $outtype == 0 ) {
			syslog( 'notice', $txt );
		} elsif( $outtype == 1 ) {
			print TXTLOG $txt . "\n";
		} elsif( $outtype == 2 ) {
			print $txt . "\n";
		}
	}

	if ( defined($opt_S) ) {
		# only run a single data-collection cycle
		# and exit
		last;
	}

	# turn on the signal handlers
	$SIG{USR1} = 'handler1';
	$SIG{USR2} = 'handler2';
	$SIG{INT}  = 'handler3';

	sleep($heartbeat);

	# turn off the signal handlers
	$SIG{USR1} = 'IGNORE';
	$SIG{USR2} = 'IGNORE';
	$SIG{INT}  = 'IGNORE';

}

foreach $o ( @objs_in, @objs_out ) {
	$o->delete();
}

if( $outtype == 0 ) {
	closelog();
} elsif( $outtype == 1 ) {
	close( TXTLOG );
}

exit;

# *********************************************************************
# *********************************************************************
# *********************************************************************

sub handler1 {

	# do nothing on SIGUSR1
	# : however, this will wake up the
	#   process (exit from the sleep call)
	#   and start a new round of data collection
	if( $outtype == 0 ) {
		syslog( 'info', 'daemon caught SIGUSR1/handler1/wake' );
	} elsif( $outtype == 1 ) {
		print TXTLOG "daemon caught SIGUSR1/handler1/wake\n";
	} elsif( $outtype == 2 ) {
		print "damone caught SIGUSR1/handler1/wake\n";
	}
}

sub handler2 {

	# on USR2, re-read the config file
	local $SIG{USR1} = 'IGNORE';
	local $SIG{USR2} = 'IGNORE';
	local $SIG{INT}  = 'IGNORE';

	# uses same cfgfile as at initial run
	our @objs = ();
	require $cfgfile;

	# note that handlers are only 'on' during the sleep call
	# so there shouldn't be any race conditions here
	if( $outtype == 0 ) {
		syslog( 'info', 'daemon caught SIGUSR2/handler2/reread-cfg' );
	} elsif( $outtype == 1 ) {
		print TXTLOG "daemon caught SIGUSR2/handler2/reread-cfg\n";
	} elsif( $outtype == 2 ) {
		print "daemon caught SIGUSR2/handler2/reread-cfg\n";
	}
}

sub handler3 {

	# on INT, delete the objs and exit
	local $SIG{USR1} = 'IGNORE';
	local $SIG{USR2} = 'IGNORE';
	local $SIG{INT}  = 'IGNORE';
	my ($o);

	if( $outtype == 0 ) {
		syslog( 'info', 'daemon caught SIGINT/handler3/exit' );
		closelog();
	} elsif( $outtype == 1 ) {
		print TXTLOG "daemon caught SIGINT/handler3/exit\n";
		close( TXTLOG );
	} elsif( $outtype == 2 ) {
		print "daemon caught SIGINT/handler3/exit\n";
	}

	foreach $o (@objs) {
		$o->delete();
	}

	exit;
}
