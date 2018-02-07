#!/usr/bin/perl
#
# (C) 2010-2012, John Pormann, Duke University
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
# RCSID $Id: dlogger.pl 656 2013-06-25 14:12:47Z jbp $
#
# dlogger.pl -- perl-based daemon/monitor/logger for the DSCR
#    with syslog functionality

#use strict;

use IO::Handle;
use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );

use FindBin ();
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../lib/memrec";
#use lib "$FindBin::Bin/../lib/memrec_beta";

use Netsyslog;

# defaults
our $heartbeat   = 60*10;
our $inner2outer = 1;  # not used
our $loglocal    = 'local4';
our $logname     = 'dlogger.pl';
our $loghost     = 'localhost';
our $logport     = 514;
our $verbose     = 0;
our $linesz      = 5;
our $output      = 'syslog';
our $outfile     = 'logfile.txt';
our $cfgfile     = "$FindBin::Bin/../etc/dlogger.cfg.pl";
our $sortoutput  = 0;
our $showxid     = 1;
our $showkeys    = 1;

#
# can override with config file or cmdline args
our @objs  = ();

#
# get command-line options
getopts('vVXhd:i:f:l:n:o:F:H:P:DS');
if( defined($opt_h) ) {
	print "usage:  $0 [opts]\n"
	  .   "   -d nsec      set delay between iters (default=$heartbeat)\n"
	  .   "   -i num       set num inner to outer iters (default=$inner2outer)\n"
	  .   "   -f file      set config file (default=$cfgfile)\n"
	  .   "   -o outtype   set output type (default=$output)\n"
	  .   "   -l localN    set syslog facility [*] (default=$loglocal)\n"
	  .   "   -n logname   set logger name [*] (default=$logname)\n"
	  .   "   -F filename  set output file name [**] (default=$outfile)\n"
	  .   "   -H loghost   set the host to forward to [***] (default=$loghost)\n"
	  .   "   -P logport   set the port to forward to [***] (default=$logport)\n"
	  .   "   -S           run a single data-collection cycle\n"
	  .   "   -D           don't daemonize, stay in foreground\n"
	  .   "   -v           verbose output\n"
	  .   "   -V           really verbose output\n"
	  .   "output type is one of {syslog,file,stdout,net}\n"
	  .   "[*] only required for output=='syslog'\n"
	  .   "[**] only required for output=='file'\n"
	  .   "[***] only required for output='net'\n";
	exit( 1 );
}

#
# first, check if there is a config file to read
if ( defined($opt_f) ) {
	$cfgfile = $opt_f;
}
if( -r $cfgfile ) {
	require $cfgfile;
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
if ( defined($opt_i) ) {
	$inner2outer = $opt_i + 0;
}
if ( defined($opt_l) ) {
	$loglocal = $opt_l;	
}
if ( defined($opt_n) ) {
	$logname = $opt_n;
}
if ( defined($opt_H) ) {
	$loghost = $opt_H;
}
if ( defined($opt_P) ) {
	$logport = $opt_P;
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
# a little error-checking
if( $loglocal =~ m/^local[0-7]$/ ) {
	# ok .. looks like a valid identifier
} else {
	print STDERR "** Error: loglocal/-l must be local0 through local7\n";
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
} elsif( $output =~ m/net/i ) {
	$outtype = 3;
} else {
	print STDERR "** Error: output/-o must be one of {syslog,file,stdout,net}\n";
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
my $netlog_obj = 'X';
if( $outtype == 0 ) {
	openlog( $logname, 'ndelay,pid', $loglocal );
	syslog( 'info', 'logging process starting' );
} elsif( $outtype == 1 ) {
	open( TXTLOG, ">$outfile" );
	$old_fh = select( TXTLOG );
	$| = 1;
	select( $old_fh );
	print TXTLOG "logging process starting\n";
} elsif( $outtype == 2 ) {
	print "logging process starting\n";
} elsif( $outtype == 3 ) {
	$netlog_obj = new Netsyslog( Facility=>$loglocal,
		SyslogPort=>$logport,
		Name=>$logname, SyslogHost=>$loghost, Priority=>'info' );
	$netlog_obj->send( 'logging process starting' );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# we need a communication link (pipe) 
# between collector and timer processes
pipe( READER, WRITER );
READER->autoflush(1);
WRITER->autoflush(1);

# now fork the child/timer-pid
our $pid;
$pid = fork();
if( not $pid ) {
	# child
	close( READER );
	if( $verbose ) {
		print STDERR "Child/timer is starting\n";
	}
	while( 1 ) {
		# timer-pid catches handler1 and triggers the next collection round
		$SIG{USR1} = 'handler1';
		$SIG{USR2} = 'IGNORE';  # handled by main/collector-pid
		$SIG{INT}  = 'IGNORE';  # handled by main/collector-pid
		
		sleep($heartbeat);
		if( $verbose > 10 ) {
			print STDERR "Child/timer is triggering parent\n";
		}
		print WRITER "\n";
	}
	exit( 1 );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# main loop for parent/collector-pid
close( WRITER );

#
# install signal handlers:
$SIG{USR1} = 'IGNORE';   # handled by the timer-pid
$SIG{USR2} = 'handler2';
$SIG{INT}  = 'handler3';
our $sigusr2_flag = 0;

my $tstamp = time();
my %data = ();
my ( $o, $k, $v, $txt, $n, $itr );

if ($verbose) {
	print "Entering main loop...\n";
}
while (1) {
	#
	# get data from all objects
	$tstamp = time;
	if( $verbose > 10 ) {
		print STDERR "Pulling data ($tstamp)\n";
	}
	%data                = ();
	$data{'tstamp'}      = $tstamp;
	foreach $o ( @objs ) {
		$o->getdata( \%data );
	}
	
	if( $showxid ) {
		$txt = "xid=$tstamp ";
	} else {
		$txt = '';
	}

	$n   = 0;
	if( $sortoutput == 0 ) {
		@keylist = keys(%data);
	} else {
		@keylist = sort(keys(%data));
	}
	foreach $k ( @keylist ) {
		if ( $k eq 'tstamp' ) {
			next;
		}
		$v = $data{$k};
		if( length($v) > 40 ) {
			# if the current output is large,
			# first dump the previous line
			if( $n > 0 ) {
				&write_log( $txt );
			}
			if( $showxid ) {
				$txt = "xid=$tstamp ";
			} else {
				$txt = '';
			}
			$n   = 0;			
		}
		
		if( $showkeys ) {
			if( $v eq '' ) {
				$txt .= $k . ' ';
			} else {
				$txt .= "$k=$v ";
			}
		} else {
			$txt .= $v . ' ';			
		}
		
		$n++;
		if ( ($n == $linesz) or (length($v)>40) ) {
			&write_log( $txt );
			if( $showxid ) {
				$txt = "xid=$tstamp ";
			} else {
				$txt = '';
			}
			$n   = 0;
		}
	}
	if ( $n > 0 ) {
		&write_log( $txt );
	}

	if ( defined($opt_S) ) {
		# only run a single data-collection cycle
		# and exit
		last;
	}

	&wait_for_timestep();
	
	if( $sigusr2_flag == 1 ) {
		&reread_cfg();
		$SIG{USR2} = 'handler2';
		$sigusr2_flag = 0;	
	}

}

foreach $o ( @objs ) {
	$o->delete();
}

if( $outtype == 0 ) {
	closelog();
} elsif( $outtype == 1 ) {
	close( TXTLOG );
}

kill( KILL, $pid );

exit;

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

sub reread_cfg {
	my ($o);
	our @objs;

	foreach $o ( @objs ) {
		$o->delete();
	}

	# uses same cfgfile as at initial run
	@objs = ();
	do $cfgfile;

	# note that handlers are only 'on' during the sleep call
	# so there shouldn't be any race conditions here
	&write_log( 'daemon re-read config file' );
	
	return;
}

sub handler1 {

	# do nothing on SIGUSR1
	# : however, this will wake up the
	#   process (exit from the sleep call)
	#   and start a new round of data collection
	&write_log( 'daemon caught SIGUSR1/handler1/wake' );

	return;
}

sub handler2 {
	our $sigusr2_flag;
	our $pid;  # child/timer pid
	
	# trigger a reload at next iteration
	$sigusr2_flag = 1;
	
	# kick the timer-pid to trigger a new collection round
	# : which will cause the actual re-read of the cfg file 
	kill( USR1, $pid );
	
	# note that handlers are only 'on' during the sleep call
	# so there shouldn't be any race conditions here
	&write_log( 'daemon caught SIGUSR2/handler2/reread-cfg' );
	
	return;
}

sub handler3 {
	my ($o);
	our @objs;
	our $pid;  # child/timer pid

	# on INT, delete the objs and exit

	&write_log( 'daemon caught SIGINT/handler3/exit' );

	foreach $o (@objs) {
		$o->delete();
	}

	kill( KILL, $pid );

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
	} elsif( $outtype == 3 ) {
		$netlog_obj->send( $txt, Priority=>'notice' );	
	}
	
	return;
}
