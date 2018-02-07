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
# RCSID $Id: smartctl.pm 429 2012-08-15 15:48:47Z jbp $

package smartctl;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

$smart_cmd = '/usr/sbin/smartctl';

sub prep {
}

sub new {
	my $class = shift;
	my $self  = {};          # allocate new hash for object
	my ($fp,$c);

	open( $fp, '/proc/diskstats' )
	  or print STDERR "** Error: cannot open file [/proc/diskstats]\n";
	$c = 0;
	while (<$fp>) {
		if ( $_ =~ m/\s+([sh]d\w\d)\s+(.*)/ ) {
			$self->{"hd_$1"} = 0;
			$c++;
		}
	}

	$self->{'num_hd'} = $c;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $num_hd = $self->{'num_hd'};
	my ($fp,$err_ttl,$k,$hd,$c);
	my @fld = ();

	$err_ttl = 0;

	$c = 0;
	foreach $k ( sort(keys(%self)) ) {
		if( $k =~ m/^hd_(.*)/ ) {
			$hd = $1;
		}
		open( $fp, "$smart_cmd -l error $hd 2>&1 |" );
		# skip first line (header)
		<$fp>;
		$_ = <$fp>;
		close($fp);
		
	}

	$dref->{'hd_errs_ttl'} = $err_ttl;
	$dref->{'hd_errs_list'} = join(',',@fld);

	return( 0 );
}

sub delete {

}

1;

