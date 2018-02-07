#!/usr/bin/perl
#
# (C) 2011-2012, John Pormann, Duke University
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
# RCSID $Id: kvgrep.pl 430 2012-08-15 15:50:03Z jbp $
#
# kvgrep - a grep-like tool for the key/value output from the memrec tools


use Getopt::Std;
getopts('hAOCKt:f:k:');

if( defined($opt_h) ) {
	print "usage:  kvgrep [opts] keylist filename\n"
	  .   "   -O                  (OR) any key must be present\n"
	  .   "   -C                  output CSV data\n"
	  .   "   -A                  output all keys for each line\n"
	  .   "   -K                  don't show 'key=' in output\n"
	  .   "   -t key              key value for joining multi-line transactions\n"
	  .   "   -k key,key,...      list of keys\n"
	  .   "   -f file             use specified file\n";
	exit( 0 );
}

if( not defined($opt_k) ) {
	# no keylist given by -k, try ARGV
	if( scalar(@ARGV) > 0 ) {
		$opt_k = shift( @ARGV );
	}
}

if( not defined($opt_f) ) {
	# no file given by -f, try ARGV
	if( scalar(@ARGV) > 0 ) {
		$opt_f = shift( @ARGV );
	}
}

if( not defined($opt_k) ) {
	print "** Error: must specify keylist to scan for\n";
	exit( -1 );
}
if( not defined($opt_f) ) {
	print "** Error: must specify file to scan\n";
	exit( -2 );
}

if( defined($opt_C) ) {
	$opt_K = 1;
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

open( FP, "$opt_f" ) 
	or die "** Error: cannot read file $opt_f\n";

%keylist = ();
$nkeys = 0;
foreach $k ( split( ',', $opt_k ) ) {
	$keylist{$k} = $nkeys;    # we'll use this to re-order the output
	$nkeys++;
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

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

# catch the last transaction (if needed)
if( defined($opt_t) ) {
	# xid and last_xid are already filled in
	if( $xid eq $last_xid ) {
		&process_line( $xtext );
	}
}

close( FP );

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

sub process_line {
	my $l = shift( @_ );
	my ($flag,$kv,$k,$v,$i,$fval,$sep);
	my @fld = ();
	my @output = ();
		
	if( defined($opt_O) ) {
		# OR - only need one of the keys to match
		$fval = 1;
	} else {
		# default is AND - need all keys to match
		$fval = $nkeys;
	}
	if( defined($opt_C) ) {
		$sep = ',';
	} else {
		$sep = ' ';
	}

	@fld = split( /\s+/, $l );
	
	$flag = 0;
	foreach $kv ( @fld ) {
		if( $kv =~ m/\=/ ) {
			($k,$v) = split( '=', $kv );
		} else {
			$k = $kv;
			$v = '';
		}
		
		if( exists($keylist{$k}) ) {
			$i = $keylist{$k};
			$output[$i] = $kv;
			$flag++;
		}
	}	
	
	if( $flag >= $fval ) {
		if( defined($opt_A) ) {
			if( defined($opt_K) ) {
				map { $_ =~ s/(.*?)\=// } @fld;
			}
			print join( $sep, @fld );
		} else {
			if( defined($opt_K) ) {
				map { $_ =~ s/(.*?)\=// } @output;
			}
			print join( $sep, @output );
		}
		print "\n";
	}
	
	return;
}

