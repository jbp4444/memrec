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
# RCSID $Id: forktest.pl 391 2012-01-12 15:25:59Z jbp $
#
# dlogger.pl -- perl-based daemon/monitor/logger for the DSCR
#    with syslog functionality

#use strict;

use IO::Handle;
use Getopt::Std;
use POSIX 'setsid';
use POSIX ":sys_wait_h";

$verbose = 0;
$heartbeat = 5;
#
# get command-line options
getopts('vVXhd:');
if( defined($opt_h) ) {
	print "usage:  $0 [-d delay]\n";
	exit( 1 );
}

#
# now overwrite with cmdline args
if ( defined($opt_v) ) {
	$verbose++;
}
if ( defined($opt_V) ) {
	$verbose += 10;
}
if ( defined($opt_d) ) {
	$heartbeat = $opt_d + 0;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# we need a communication link (pipe) 
# between collector and timer processes
pipe( READER, WRITER );
#$oldh = select( READER );
#$| = 1;
#select( WRITER );
#$| = 1;
#select( $oldh );
READER->autoflush(1);
WRITER->autoflush(1);

# now fork the child/timer process
$pid = fork();
if( not $pid ) {
	# child
	close( READER );
	print "child is starting\n";
	while( 1 ) {
		print "child is sleeping\n";
		sleep($heartbeat);
		print "child is triggering parent\n";
		print WRITER "\n";
	}
	exit( 1 );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# main loop for parent
close( WRITER );

my $tstamp = time();
my ( $o, $k, $v, $txt, $n, $itr );

if ($verbose) {
	print "parent entering main loop...\n";
}
while (1) {
	print "parent is waiting for trigger\n";
	
	# make sure child/timer process is
	# still working/producing output
	&wait_for_timestep();
	
	print "parent is collecting data\n";
	sleep(1);
	print "parent is done\n";
}

kill 9, $pid;
waitpid( $pid, WNOHANG );

# *********************************************************************
# *********************************************************************
# *********************************************************************

sub wait_for_timestep {
	my ($x);
	if( eof(READER) ) {
		last;
	}
	$x = <READER>;
	return;
}

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

sub write_log {
	my $txt = shift( @_ );
	
	if( $outtype == 0 ) {
		syslog( 'notice', $txt );
	} elsif( $outtype == 1 ) {
		print TXTLOG $txt . "\n";
	} elsif( $outtype == 2 ) {
		print $txt . "\n";
	}
	
	return;
}
