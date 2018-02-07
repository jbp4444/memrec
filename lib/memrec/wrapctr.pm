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
# RCSID $Id: wrapctr.pm 421 2012-05-21 13:58:30Z jbp $

package wrapctr;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw( &new );

my $ULONG_MAX = ( ~0 );

# no prep function -- not needed

sub new {
	my $class = shift;
	my $nv    = shift( @_ );
	my $self = {};
	
	$self->{'v'} = $nv + 0;
	
	bless( $self, $class );
	return $self;
}

sub update {
	my $self = shift;
	my $nv = shift( @_ );
	my ($d,$ov);

	$ov = $self->{'v'};
	
	if ( $nv >= $ov ) {
		$d = $nv - $ov;
	}
	else {

		# OVERFLOW
		$d = ( $ULONG_MAX - $nv ) + $ov;
	}
	
	$self->{'v'} = $nv;
	$self->{'d'} = $d;
	
	return ($d);
}

sub lastval {
	my $self = shift;
	return( $self->{'v'} );
}
sub setval {
	my $self = shift;
	my $val = shift;
	my $x = $self->{'v'};
	$self->{'v'} = $val + 0;
	$self->{'d'} = 0;
	return( $x );
}
sub lastdiff {
	my $self = shift;
	return( $self->{'d'} );
}

sub delete {

}

1;
