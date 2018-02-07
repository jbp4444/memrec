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
# RCSID $Id: fltrec.pl 552 2013-01-11 14:50:38Z jbp $
#
# fltrec - flight-recorder script to track usage of a running program (through
#		/proc/pid/status) and write it to a text file


use Getopt::Std;
use POSIX ":sys_wait_h";

use FindBin ();
use lib "$FindBin::Bin/../lib/modules";

use cpuinfo;
use meminfo;

getopts('hvVtscKMGALd:o:f:P:T:');

$outfile = 'memprofile';
$outext  = '.txt';
$outsep  = ' ';
@outflds = ( 'VmSize' );
$delay = 15;
$verbose = 0;

if( defined($opt_h) ) {
	print "usage: $0 [opts] prog\n"
	  .   "   -d #        delay (seconds, default=$delay)\n"
	  .   "   -o file     output filename (default=$outfile)\n"
	  .   "   -s          output separator is a space (default, .txt)\n"
	  .   "   -t          output separator is a tab (.txt)\n"
	  .   "   -c          output separator is a comma (.csv)\n"
	  .   "   -K          output in KB\n"
	  .   "   -M          output in MB\n"
	  .   "   -G          output in GB\n"
	  .   "   -L          list all available fields and exit\n"
	  .   "   -A          output all fields\n"
	  .   "   -f f1,f2    output selected fields\n"
	  .   "   -v          verbose output\n"
	  .   "   -V          really verbose output\n";
	exit( 1 );
}

if( defined($opt_v) ) {
	$verbose++;
}
if( defined($opt_V) ) {
	$verbose += 10;
}
if( defined($opt_T) ) {
	$outsep = "\t";
	$outext = '.txt';
}
if( defined($opt_S) ) {
	$outsep = ' ';
	$outext = '.txt';
}
if( defined($opt_C) ) {
	$outsep = ',';
	$outext = '.csv';
}
if( defined($opt_o) ) {
	$outfile = $opt_o;
	$outext  = '';
}
if( defined($opt_f) ) {
	@outflds = split( ',', $opt_f );
}
if( defined($opt_A) ) {
	$opt_A = 1;
} else {
	$opt_A = 0;
}
if( defined($opt_d) ) {
	$delay = $opt_d + 0;
	if( $opt_d =~ m/[mM]/ ) {
		$delay *= 60;
	} elsif( $opt_d =~ m/[hH]/ ) {
		$delay *= 60*60;
	}
}
$watch_pid = 0;
if( defined($opt_P) ) {
	$watch_pid = $opt_P + 0;
}
$t0 = time();
if( defined($opt_T) ) {
	$t0 = $opt_T + 0;
}
$div = 1;
if( defined($opt_K) ) {
	$div = 1024;
}
if( defined($opt_M) ) {
	$div = 1024*1024;
}
if( defined($opt_G) ) {
	$div = 1024*1024*1024;
}

if( defined($opt_L ) ) {
	# dummy command just to get list of known fields
	$cmd = '/bin/sleep 1';
	$opt_A = 1;
	if( $verbose == 0 ) {
		$verbose = 1;
	}
} else {
	$cmd = join( ' ', @ARGV );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

if( $watch_pid == 0 ) {
	$pid = fork();
	if( $pid == 0 ) {
		# child process ... runs the program
		exec( $cmd );
	
		# should never get here
		exit( 111 );
	}
	$outfile = $outfile . $outext;
} else {
	$pid = $watch_pid;
	$outfile = $outfile . '.' . $pid . $outext;
}

# turn off the signal handlers for now
#$SIG{USR1} = 'IGNORE';
#$SIG{USR2} = 'IGNORE';
#$SIG{INT}  = 'IGNORE';
# ignore some common "issues" with forking child processes
#$SIG{PIPE} = 'IGNORE';

$child_flag = 1;
$SIG{CHLD} = \&child_handler;

open( FPO, ">$outfile" );
select( FPO );
$| = 1;

if( $verbose > 9 ) {
	print "# parent pid ($$)\n";
	print "# child pid ($pid)\n";
}

$ppid_obj = pidmem->new( $pid );
@par_objs = ();
push( @par_objs, cpuinfo->new() );
push( @par_objs, netinfo->new() );
push( @par_objs, diskstats->new() );

%chld_objs = ();
$firsttime = 1;

$last_tstamp = time();

while( $child_flag ) {
	$tstamp = time() - $t0;
	if( $last_tstamp == $tstamp ) {
		# MAJOR KLUDGE to avoid div-by-zero errors
		$tstamp++;
	}
	
	%foundpid = ();
	$e = &find_children( $pid, \%foundpid );
	if( $verbose > 10 ) {
		@plist = keys(%foundpid);
		print "# pidlist: @plist\n";
	}
	foreach $p ( keys(%foundpid) ) {
		if( not exists($chld_objs{$p}) ) {
			# this is a new child pid
			$chld_objs{$p} = pidmem->new( $p );
		}
	}

	# get parent data
	%pdata = ();
	$pdata{'tstamp'} = $tstamp;
	$pdata{'last_tstamp'} = $last_tstamp;
	foreach $p ( @par_objs ) {
		$pe = $p->getdata( \%pdata );
		if( $pe ) {
			print "# obj $p threw $pe\n";
		}
	}
	$pe = $ppid_obj->getdata( \%pdata );
	if( $pe ) {
		print "# ppid_obj $p threw $pe\n";
	}
	
	# get child data
	%cdata = ();
	foreach $p ( keys(%chld_objs) ) {
		$b = $chld_objs{$p};
		$ce = $b->getdata( \%cdata );
		if( $ce ) {
			print "# pid $p threw $ce\n";
		}
	}
	
	if( $opt_A ) {
		@outflds = ( keys(%pdata), keys(%cdata) );
		$opt_A = 0;  # don't need to recalc @outflds again
	}
	if( $firsttime and $verbose ) {
		print "# tstamp$outsep" . join($outsep,@outflds) . "\n";
		$firsttime = 0;
	}
	
	# get the comma/space/tab-separated text
	$b = "$tstamp";
	foreach $x ( @outflds ) {
		$y = ( $pdata{"$x"} + 0 ) / $div;
		$b .= $outsep . $y;
	}
	$mref = $cdata{'pidmem'};
	foreach $x ( @outflds ) {
		$y = ( $cdata{"$x"} + 0 ) / $div;
		$b .= $outsep . $y;
	}
	print $b . "\n";

	if( $pe ) {
		last;
	}

	# turn on the signal handlers
	#$SIG{USR1} = "null_handler";
	#$SIG{USR2} = "handler2";
	#$SIG{INT}  = "handler3";

	sleep( $delay );

	# turn off the signal handlers
	$SIG{USR1} = "IGNORE";
	$SIG{USR2} = "IGNORE";
	#$SIG{INT}  = "IGNORE";

	$last_tstamp = $tstamp;
}

print "\n";
close( FPO );

if( defined($opt_L) ) {
	select STDOUT;
	system( "/usr/bin/head -1 $outfile" );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
 # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub find_children {
	my $pid = shift( @_ );
	my $foundpid = shift( @_ );
	my ($p,$x,$l);

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

	if( $l == 0 ) {
		return( -1 );
	}
	return( 0 );
}

sub null_handler {
	# do nothing, e.g., on SIGUSR1
	# : however, this will wake the
	#   process from the sleep call
}

sub handler2 {
	local $SIG{USR1} = "IGNORE";
	local $SIG{USR2} = "IGNORE";
	local $SIG{INT}  = "IGNORE";
}

sub child_handler {
	# from http://perldoc.perl.org/perlipc.html#Background-Processes
	my $w;
	while( ($w=waitpid(-1,WNOHANG)) > 0 ) {
		if( $w == $pid ) {
			$child_flag = 0;
		}
	}
	$SIG{CHLD} = \&child_handler; 
}

