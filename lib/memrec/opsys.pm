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
# RCSID $Id: opsys.pm 424 2012-08-15 14:04:39Z jbp $

package opsys;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

sub prep {
}

sub new {
	my $class = shift;
	my $self = {};
	my ($fp,$opsys,$uname);
	
	$opsys = 'unknown-os';
	$uname = 'unknown-os';
	
	if( -e '/etc/redhat-release' ) {
		open( $fp, '/etc/redhat-release' );
		$_ = <$fp>;
		chomp( $_ );
		$opsys = lc( $_ );
		close($fp);
		$opsys =~ s/[\(\)]//g;
		$opsys =~ s/ /-/g;
	}
	
	open( $fp, '/bin/uname -r |' );
	$_ = <$fp>;
	chomp( $_ );
	$uname = lc( $_ );
	
	$self->{'opsys'} = $opsys;
	$self->{'uname'} = $uname;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($k,$v);
	
	while( ($k,$v) = each %$self ) {
		$dref->{$k} = $v;
	}

	return( 0 );	
}

sub delete {
	
}

1;
