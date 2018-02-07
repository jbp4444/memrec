#!/usr/bin/perl
#
# (C) 2012, John Pormann, Duke University
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
# RCSID $Id: nvidiagpu.pm 608 2013-04-23 19:41:39Z jbp $

package nvidiagpu;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $nv_cmd = '/usr/bin/nvidia-smi';
my $nv_args = '-q';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'nv_cmd' ) {
		$nv_cmd = $val;
	} elsif( $key eq 'nv_args' ) {
		$nv_args = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $self  = {};          # allocate new hash for object
	my ($n,$type);

	$n = 0;
	$type = '';
	
	open( $pp, "$nv_cmd $nv_args |" );
	while( <$pp> ) {
		chomp( $_ );
		if( $_ =~ m/Attached GPUs\s+\:\s+(.*)/ ) {
			$n = $1;
		} elsif( $_ =~ m/Product Name\s+\:\s+(.*)/ ) {
			$type = 'nvidia-' . lc( $1 );
			$type =~ s/\s+/-/g;
		}
	}
	close( $pp );

	$self->{'num_gpu'} = $n;
	$self->{'gpumodel'} = $type;

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

