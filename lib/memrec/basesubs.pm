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
# RCSID $Id: basesubs.pm 598 2013-04-08 15:46:04Z jbp $

package basesubs;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( &delta &convert_to_bytes &round_0 &round_00 &round0 &round00 &round000 
	&max3 &max4 &histogram &convert_to_yesno );

my $ULONG_MAX = ( ~0 );

sub delta {
	my $x = shift(@_);   # bigger number (more recent counter)
	my $y = shift(@_);   # smaller number (less recent counter)
	my ($d);
	if ( $x >= $y ) {
		$d = $x - $y;
	}
	else {

		# OVERFLOW
		$d = ( $ULONG_MAX - $y ) + $x;
	}
	return ($d);
}

sub convert_to_bytes {
	my $v = shift( @_ );
	my $m = shift( @_ );
	if( $m =~ m/[kK]/ ) {
		$v *= 1024;
	} elsif( $m =~ m/[mM]/ ) {
		$v *= 1024*1024;
	} elsif( $m =~ m/[gG]/ ) {
		$v *= 1024*1024*1024;
	}
	return( $v );
}

sub convert_to_yesno {
	my $val = shift( @_ );
	my ($rtn);
	if( $val =~ m/^[tTyY1]/ ) {
		$rtn = 1;
	} elsif( $val =~ m/^[fFnN0]/ ) {
		$rtn = 0;
	} else {
		print STDERR "* Warning: unknown yes/no value [$val] .. assuming No (0)\n";
		$rtn = 0;
	}
	return( $rtn );	
}

sub max3 {
	my $a = shift(@_);
	my $b = shift(@_);
	my $c = shift(@_);
	if( $b > $a ) {
		$a = $b;
	}
	if( $a > $c ) {
		return( $a );
	}
	return( $c );
}

sub max4 {
	my $a = shift(@_);
	my $b = shift(@_);
	my $c = shift(@_);
	my $d = shift(@_);
	if( $b > $a ) {
		$a = $b;
	}
	if( $d > $c ) {
		$c = $d;
	}
	if( $a > $c ) {
		return( $a );
	}
	return( $c );
}

sub round_0 {
	my $x = shift( @_ );
	return( int($x/10+0.5)*10 );
}
sub round_00 {
	my $x = shift( @_ );
	return( int($x/100+0.5)*100 );
}
sub round0 {
	my $x = shift( @_ );
	return( int($x*10+0.5)/10 );
}
sub round00 {
	my $x = shift( @_ );
	return( int($x*100+0.5)/100 );
}
sub round000 {
	my $x = shift( @_ );
	return( int($x*1000+0.5)/1000 );
}

sub histogram {
	my $nbins = shift( @_ );
	my $mn = shift( @_ );
	my $mx = shift( @_ );
	my @data = @_;
	my ($binsz,$d,$i);
	my @hist = ();

	for($i=0;$i<4;$i++) {
		$hist[$i] = 0;	
	}
	$binsz = ($mx-$mn)/$nbins;
	
	foreach $d ( @data ) {
		$i = int( $d/$binsz );
		$hist[$i]++;
	}	

	return( join(',',@hist) );	
}

1;
