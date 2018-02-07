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
# RCSID $Id: memrec.pl 656 2013-06-25 14:12:47Z jbp $
#
# memrec - flight-recorder script to track memory usage of a running program (through
#		/proc/pid/status) and write it to a text file

#use strict;

use IO::Handle;
use Getopt::Std;
use POSIX 'setsid';
use POSIX ':sys_wait_h';
use Sys::Syslog qw( :DEFAULT );

use FindBin ();
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../lib/memrec";

# always needed
use pidmem;

# defaults
our $heartbeat   = 30;
our $inner2outer = 0;  # not used
our $verbose     = 0;
our $linesz      = 5;
our $outfile     = 'logfile.txt';
our $cfgfile     = '/usr/local/etc/memrec.cfg.pl';
our $sortoutput  = 0;
our $showxid     = 1;
our $showkeys    = 1;

#
# can override with config file
our @objs  = ();

#
# get command-line options
getopts('vVhd:f:o:');
if( defined($opt_h) ) {
	print "usage:  $0 [opts]\n"
	  .   "   -d delay     set the delay (seconds, default=$heartbeat)\n"
	  .   "   -f cfg       use an alternate config file\n"
	  .   "   -o filename  set output file name (default=$outfile)\n"
	  .   "   -v           verbose output\n"
	  .   "   -V           really verbose output\n";
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
if ( defined($opt_o) ) {
	$outfile = $opt_o;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

$cmd = join( ' ', @ARGV );
if( $verbose ) {
	 print STDERR "cmd = [$cmd]\n";
}
#
# fork off the child process
my $pid = fork();
if ( $pid == 0 ) {
	# child process
	# from here on down, this is the child only
	setsid();
	#open( STDIN,  "</dev/null" );
	#open( STDOUT, ">/dev/null" );
	#open( STDERR, ">&STDOUT" );

	exec( "$cmd" );
	
	exit(0);
}
if( $verbose ) {
	print STDERR "child pid: $pid\n";
}

# turn off the signal handlers for now
$SIG{USR1} = 'IGNORE';
$SIG{USR2} = 'IGNORE';
$SIG{INT}  = 'IGNORE';

# ignore "Broken Pipe" signals so it doesn't crash the program
$SIG{PIPE} = 'IGNORE';

$| = 1;

# start up the output system
open( TXTLOG, ">$outfile" );
print STDERR "logging process starting\n";

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# we need a communication link (pipe) 
# between collector and timer processes
pipe( READER, WRITER );
READER->autoflush(1);
WRITER->autoflush(1);

# now fork the child/timer-pid
our $timer_pid;
$timer_pid = fork();
if( not $timer_pid ) {
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
		$SIG{CHILD} = 'IGNORE'; # handled by main/collector-pid
		
		sleep($heartbeat);
		if( $verbose > 10 ) {
			print STDERR "Child/timer is triggering parent\n";
		}
		print WRITER "\n";
	}
	exit( 1 );
}

# parent attaches to first child
$ppid_obj = pidmem->new( $pid );

# get ready for child objects
%chld_objs = ();

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# main loop
close( WRITER );

#
# install signal handlers:
$SIG{USR1} = 'IGNORE';   # handled by the timer-pid
$SIG{USR2} = 'IGNORE';
$SIG{INT}  = 'handler3';
$child_flag = 1;
$SIG{CHLD} = 'child_handler';

my $tstamp = time();
my %data = ();
my ( $o, $k, $v, $txt, $n, $itr );

if ($verbose) {
	print STDERR "Entering main loop...\n";
}
while ( $child_flag == 1 ) {
	$tstamp = time;
	if( $verbose > 10 ) {
		print STDERR "Pulling data ($tstamp)\n";
	}	
	%data                = ();
	$data{'tstamp'}      = $tstamp;
	
	%foundpid = ();
	#$e = &find_children( $pid, \%foundpid );
	#if( $verbose > 10 ) {
	#	@plist = keys(%foundpid);
	#	print STDERR "# pidlist: @plist\n";
	#}
	#foreach $p ( keys(%foundpid) ) {
	#	if( not exists($chld_objs{$p}) ) {
	#		# this is a new child pid
	#		$chld_objs{$p} = pidmem->new( $p );
	#	}
	#}
	
	foreach $o ( @objs ) {
		$pe = $o->getdata( \%data );
		if( ($verbose>10) and $pe ) {
			print STDERR "# obj $p threw $pe\n";
		}
	}
	$pe = $ppid_obj->getdata( \%data );
	if( ($verbose>10) and $pe ) {
		print STDERR "# ppid_obj $p threw $pe\n";
	}
	
	# get child data
	%cdata = ();
	foreach $p ( keys(%chld_objs) ) {
		$b = $chld_objs{$p};
		$ce = $b->getdata( \%cdata );
		if( ($verbose>10) and $ce ) {
			print STDERR "# pid $p threw $ce\n";
		}
	}
	
	# TODO:  need to accumulate child data better
	foreach $d ( keys(%cdata) ) {
		$data{"chld_$d"} += $cdata{$d};
	}

	if( $showxid ) {
		$txt = "xid=$tstamp ";
	} else {
		$txt = '';
	}

	$n   = 0;
	while ( ( $k, $v ) = each %data ) {
		if ( $k eq 'tstamp' ) {
			next;
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
		if ( $n == $linesz ) {
			print TXTLOG $txt . "\n";
			if( $showxid ) {
				$txt = "xid=$tstamp ";
			} else {
				$txt = '';
			}
			$n   = 0;
		}
	}
	if ( $n > 0 ) {
		print TXTLOG $txt . "\n";
	}

	&wait_for_timestep();

	if( $verbose ) {
		print STDERR "next timestep [$child_flag]\n";
	}

}

if( $verbose ) {
	print STDERR "logging complete\n";
}

# for "normal" exits, we need to terminate the timer too
kill( KILL, $timer_pid );

foreach $o ( @objs ) {
	$o->delete();
}

close( TXTLOG );

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

sub handler1 {
	# do nothing on SIGUSR1
	# : however, this will wake up the
	#   process (exit from the sleep call)
	#   and start a new round of data collection
}

sub handler3 {
	my ($o);
	our @objs;
	our $pid;  # child/timer pid

	# on INT, delete the objs and exit

	print STDERR "daemon caught SIGINT/handler3/exit\n";
	close( TXTLOG );

	foreach $o (@objs) {
		$o->delete();
	}

	kill( KILL, $timer_pid );
	kill( KILL, $pid );

	exit;
}

sub child_handler {
	my ($w);

	print STDERR "pid [$pid]  timer_pid [$timer_pid]  child_flag [$child_flag]\n";
	
	if( $verbose ) {
		print STDERR "caugh SIGCHILD\n";
	}
	
	# from http://perldoc.perl.org/perlipc.html#Background-Processes
	while( ($w=waitpid(-1,WNOHANG)) > 0 ) {
		print STDERR "caught child [$w]\n";
		if( $w == $pid ) {
			$child_flag = 0;
			print STDERR "child_flag [$child_flag]\n";
		}
	}

	print STDERR "end of child_handler\n";

	$SIG{CHLD} = 'child_handler';
}

sub find_children {
	my $pid = shift( @_ );
	my $foundpid = shift( @_ );
	my ($p,$x,$l);

	$SIG{CHLD} = 'IGNORE';

	open( PSP, "/usr/bin/pstree -c -p $pid |" );
	$l = 0;
	while( <PSP> ) {
		chomp( $_ );
		$x = $_;
		while( $x =~ m/\((\d+)\)/ ) {
			$p = $1 + 0;
			if( $p != $pid ) {
				$foundpid->{$p} = 1;
			}
			$x =~ s/\($p\)//;
		}
		$l++;
	}
	close( PSP );

	$SIG{CHLD} = \&child_handler;

	if( $l == 0 ) {
		return( -1 );
	}
	return( 0 );
}


