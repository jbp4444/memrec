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
# RCSID $Id: const.pm 421 2012-05-21 13:58:30Z jbp $

package const;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

sub prep {
}

sub new {
	my $class = shift;
	my $c1 = shift( @_ );
	my $c2 = shift( @_ );
	my $c3 = shift( @_ );
	my $self = {};
	
	if( $c1 !~ m/^\d/ ) {
		$c1 = 1;
	}
	if( $c2 !~ m/^\d/ ) {
		$c2 = 10;
	}
	if( $c3 !~ m/^\d/ ) {
		$c3 = 100;
	}

	$self->{'c1'} = $c1;
	$self->{'c2'} = $c2;
	$self->{'c3'} = $c3;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	
	$dref->{'const1'} = $self->{'c1'};
	$dref->{'const2'} = $self->{'c2'};
	$dref->{'const3'} = $self->{'c3'};

	return( 0 );	
}

sub delete {
	
}

1;
