#!/usr/bin/perl
#
# (C) 2004-2012, John Pormann, Duke University
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
# RCSID: $Id: qloadsensor.pl 89 2011-01-04 19:24:39Z jbp $
#
# qloadsensor - SGE load-sensor

use strict;

use FindBin ();
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/../lib/memrec";
#use lib "$FindBin::Bin/../lib/memrec_beta";

# use PERL5LIB env var to get to memrec/modules
# setenv PERL5LIB ${PERL5LIB}:/home/scsc/jbp1/seq/memrec/modules

#my $config_file = '/usr/local/etc/qloadsensor.cfg.pl';
my $config_file = "$FindBin::Bin/../etc/qloadsensor.cfg.pl";
if( exists($ENV{'QLOADSENSOR_CFG'}) ) {
	$config_file = $ENV{'QLOADSENSOR_CFG'};
}

if( exists($ENV{'QLOADSENSOR_MOD'}) ) {
	push( @INC, $ENV{'QLOADSENSOR_MOD'} );
}

our @objs = ();
require $config_file;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# find this host's name
# : another way to do this: `$root_dir/utilbin/$myarch/gethostname -name`
my $hostname = `uname -n`;
chomp($hostname);
# : trim off any .foo.bar.baz stuff
$hostname =~ s/(.*?)\.(.*)/$1/;

# force a flush of the print buffer for every line
# : otherwise the pipe from SGE execd won't work !!
$| = 1;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $last_tstamp = time;
my $tstamp;
my %data;
my ( $o, $k, $v );

#
# MAIN LOOP
while (1) {
	my $x = <STDIN>;
	if ( $x =~ m/^quit/ ) {
		exit(0);
	}

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

	print "begin\n";

	while( ($k,$v) = each %data ) {
		if ( ( $k eq 'tstamp' ) or ( $k eq 'last_tstamp' ) ) {
			next;
		}
		
		print "$hostname:$k:$v\n";
	}

	print "end\n";

	$last_tstamp = $tstamp;
}

foreach $o (@objs) {
	$o->delete();
}

exit(0);
