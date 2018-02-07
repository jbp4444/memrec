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
# RCSID $Id: cronlogger.pl 656 2013-06-25 14:12:47Z jbp $
#
# cronlogger.pl -- perl-based (one-time) logger for the DSCR
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

# defaults
our $heartbeat   = 30;
our $inner2outer = 5;
our $loglocal    = 'local4';
our $logname     = 'cronlogger.pl';
our $verbose     = 0;
our $linesz      = 5;
our $output      = 'syslog';
our $outfile     = 'logfile.txt';
our $cfgfile     = "$FindBin::Bin/../etc/cronlogger.cfg.pl";
our $sortoutput  = 0;
our $showxid     = 0;
our $showkeys    = 1;

#
# can override with config file or cmdline args
our @objs = ();

#
# get command-line options
getopts('vVXhf:l:n:o:F:');
if( defined($opt_h) ) {
	print "usage:  $0 [opts]\n"
	  .   "   -f file      set config file (default=$cfgfile)\n"
	  .   "   -o outtype   set output type (default=$output)\n"
	  .   "   -l localN    set syslog facility [*] (default=$loglocal)\n"
	  .   "   -n logname   set logger name [*] (default=$logname)\n"
	  .   "   -F filename  set output file name [**] (default=$outfile)\n"
	  .   "   -v           verbose output\n"
	  .   "   -V           really verbose output\n"
	  .   "output type is one of {syslog,file,stdout}\n"
	  .   "[*] only required for output=='syslog'\n"
	  .   "[**] only required for output=='file'\n";
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
} else {
	print STDERR "** Error: output/-o must be one of {syslog,file,stdout}\n";
	exit( -2 );
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# never Daemonize

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
	#syslog( 'info', 'logging process starting' );
} elsif( $outtype == 1 ) {
	open( TXTLOG, ">$outfile" );
	#print TXTLOG "logging process starting\n";
} elsif( $outtype == 2 ) {
	#print "logging process starting\n";
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
	print STDERR "Entering main loop...\n";
}
# non-loop to run a single data collection
{
	#
	# get data from all objects
	$tstamp = time;
	if( $verbose > 10 ) {
		print STDERR "Pulling data (outer-loop $tstamp)\n";
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

	# only run a single data-collection cycle
	# and exit

}

foreach $o ( @objs ) {
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

