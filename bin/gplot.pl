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
# RCSID $Id: gplot.pl 430 2012-08-15 15:50:03Z jbp $
#
# gplog - parser to read key/value pairs (from dlogger) and draw a graph
#         using gnuplot

use Getopt::Std;
getopts('ghklLATsx:y:f:t:X:Y:S:');

if( defined($opt_h) ) {
	print "usage:  gplot [opts] filename\n"
	  .   "   -x key              use 'key' for x-axis data\n"
	  .   "   -y key1,key2,...    use 'key1', 'key2', etc., for y-axis data\n"
	  .   "   -X mn:mx            set x-range (or use 'auto')\n"
	  .   "   -Y mn:mx            set y-range (or use 'auto')\n"
	  .   "   -f file             use specified file\n"
	  .   "   -t key              key value for joining multi-line transactions\n"
	  .   "   -s                  read from stdin\n"
	  .   "   -g                  plot grid lines\n"
	  .   "   -A                  plot using 'ASCII art' (text)\n"
	  .   "   -S rows,cols        like -A, but give screen size to use\n"
	  .   "   -T                  assume x is NOT time-based\n"
	  .   "   -l                  omit lines\n"
	  .   "   -L                  omit legend\n"
	  .   "   -k                  keep temp files\n";
	exit( 0 );
}

if( defined($opt_s) ) {
	# don't need a file
} else {
	if( not defined($opt_f) ) {
		# no file given by -f, try ARGV
		if( scalar(@ARGV) > 0 ) {
			$opt_f = $ARGV[0];
		}
	}
}

if( defined($opt_S) ) {
	$opt_A = 1;
}

if( not defined($opt_x) ) {
	print "** Error: must specify x-axis data\n";
	exit( -1 );
}
if( not defined($opt_y) ) {
	print "** Error: must specify y-axis data\n";
	exit( -2 );
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

if( not defined($opt_s) ) {
	open( FP, "$opt_f" ) 
		or die "** Error: cannot read file $opt_f\n";
} else {
	open( FP, "-" );
}

open( DP, ">data.$$.gp" ) 
	or die "** Error: cannot create tmp data file [data.$$.gp]\n";
open( GP, ">cmd.$$.gp" ) 
	or die "** Error: cannot create tmp cmd file [cmd.$$.gp]\n";

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

# create the data file
$min_x = 9.9e9;
$max_x = -9.9e9;
$min_y = 9.9e9;
$max_y = -9.9e9;

$last_xid = '';
$xtext = '';

while( <FP> ) {
	chomp( $_ );
	$l = ' ' . $_ . ' ';

	if( defined($opt_t) ) {
		# one key is a 'transaction' marker for multi-line events
		# : find the xid for this line
		$txt = $l;
		$txt =~ s/\s$opt_t\=(.*?)\s//;
		$xid = $1;

		if( $xid eq $last_xid ) {
			$xtext .= $l;
		} else {
			&process_line( $xtext );
			$xtext = $l;
			$last_xid = $xid;
		}

	} else {
		# parse each line separately
		&process_line( $l );
	}
	
}
close( DP );
if( not defined($opt_s) ) {
	close( FP );
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

# create command file for gnuplot
if( defined($opt_A) ) {
	$i =  '';
	if( defined($opt_S) ) {
		@list = split( ',', $opt_S );
		$i = $list[0] . ' ' . $list[1];
	}
	print GP "set term dumb $i\n";
}
if( defined($opt_g) ) {
	print GP "set grid\n";
}
if( defined($opt_X) ) {
	if( $opt_X eq 'auto' ) {
		print GP "set xrange [$min_x:$max_x]\n";
	} else {
		print GP "set xrange [$opt_X]\n";
	}
}
if( defined($opt_Y) ) {
	if( $opt_Y eq 'auto' ) {
		print GP "set yrange [$min_y:$max_y]\n";
	} else {
		print GP "set yrange [$opt_Y]\n";
	}
}
if( defined($opt_L) ) {
	#$ttxt = "title \"$opt_L\"";
	$ttxt = "notitle";
} else {
	$ttxt = "notitle";
}
if( defined($opt_l) ) {
	$opt_l = "";
} else {
	$opt_l = "with lines";
}
if( not defined($opt_T) ) {
	print GP "set xdata time\n";
}
print GP "plot \"data.$$.gp\" using (\$1-$min_x):2 $ttxt $opt_l\n";
if( defined($opt_A) ) {
	# skip the pause stmt
} elsif( defined($opt_s) ) {
	print GP "pause 1000 \"Hit ctrl-c to exit\"\n\n";	
} else {
	print GP "pause -1 \"Hit return to exit\"\n\n";
}
close( GP );

system( "gnuplot cmd.$$.gp" );

if( not defined($opt_k) ) {
	unlink( "cmd.$$.gp" );
	unlink( "data.$$.gp" );
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

sub process_line {
	my $l = shift( @_ );
	my ($x,$y);
	my @fld = ();

	$x = 'x';
	$y = 'y';
	
	if( $l =~ m/\s$opt_x\=(.*?)\s/ ) {
		# found x data item
		$x = $1 + 0;
	}
	if( $l =~ m/\s$opt_y\=(.*?)\s/ ) {
		$y = $1 + 0;
	}

	if( ($x ne 'x') and ($y ne 'y') ) {
		print DP "$x $y\n";
		
		if( $x < $min_x ) {
			$min_x = $x;
		}
		if( $x > $max_x ) {
			$max_x = $x;
		}
		if( $y < $min_y ) {
			$min_y = $y;
		}
		if( $y > $max_y ) {
			$max_y = $y;
		}
	}
	
	return;
}

