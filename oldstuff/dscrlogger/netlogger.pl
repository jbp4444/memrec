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
# RCSID $Id: netlogger.pl 189 2011-06-15 17:04:40Z jbp $
#
# netlogger.pl -- perl-based daemon/monitor/logger for the DSCR network
#    with syslog functionality

#use strict;

use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );
use Net::SNMP;

use FindBin ();
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../modules";

# defaults
our $heartbeat = 30;
our $samples_for_max = 4;
our $loglocal  = 'local4';
our $logname   = 'netlogger.pl';
our $verbose   = 0;
our $linesz    = 5;
our $cfgfile   = "$FindBin::Bin/netconfig.pl";

#
#
# get command-line options
getopts('vVF:N:XO');
if ( defined($opt_v) ) {
	$verbose++;
}
if ( defined($opt_V) ) {
	$verbose += 10;
}
if ( defined($opt_F) ) {
	$cfgfile = $opt_F;
}
if ( defined($opt_N) ) {
	$logname = $opt_N;
}
if ( defined($opt_O) ) {

	# only run one data-collection
	# so don't daemonize
	$opt_X   = 1;
	$cfgfile = "$FindBin::Bin/netconfig_once.pl";
}

# override with config file
our @objs = ();
require $cfgfile;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# Daemonize

if ( not defined($opt_X) ) {
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

# start up system logs
# deprecated: setlogsock( 'unix' );
openlog( $logname, 'ndelay,pid', $loglocal );
if ( not defined($opt_O) ) {
	syslog( 'info', 'daemon process starting' );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# main loop

my $tstamp      = time();
my $last_tstamp = $tstamp;
my %data;
my ( $o, $k, $v, $txt, $n );

if ($verbose) {
	print "Entering main loop...\n";
}
while (1) {
	$tstamp = time;

	if ( $tstamp == $last_tstamp ) {

		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$tstamp++;
	}

	%data                = ();
	$data{'tstamp'}      = $tstamp;
	$data{'last_tstamp'} = $last_tstamp;
	foreach $o (@objs) {
		$o->getdata( \%data );
	}

	$txt = "xid=$tstamp ";
	$n   = 0;
	while( ($k,$v) = each %data ) {
		if ( ( $k eq 'tstamp' ) or ( $k eq 'last_tstamp' ) ) {
			next;
		}
		$txt .= "$k=$v ";

		$n++;
		if ( $n == $linesz ) {
			syslog( 'notice', $txt );
			if ( $verbose > 10 ) {
				print "data [$txt]\n";
			}
			$txt = "xid=$tstamp ";
			$n   = 0;
		}
	}
	if ( $n > 0 ) {
		syslog( 'notice', $txt );
		if ( $verbose > 10 ) {
			print "data [$txt]\n";
		}
	}

	if ( defined($opt_O) ) {

		# only run one data-collection cycle
		# and exit
		last;
	}

	$last_tstamp = $tstamp;

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

foreach $o (@objs) {
	$o->delete();
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
	syslog( 'info', 'daemon caught SIGUSR1/handler1' );
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
	syslog( 'info', 'daemon caught SIGUSR2/handler2' );
}

sub handler3 {

	# on INT, delete the objs and exit
	local $SIG{USR1} = 'IGNORE';
	local $SIG{USR2} = 'IGNORE';
	local $SIG{INT}  = 'IGNORE';
	my ($o);

	syslog( 'info', 'daemon caught SIGINT/handler3' );

	foreach $o (@objs) {
		$o->delete();
	}

	exit;
}
