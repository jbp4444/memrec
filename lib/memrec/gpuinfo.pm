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
# RCSID $Id: gpuinfo.pm 608 2013-04-23 19:41:39Z jbp $

package gpuinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

# for now, use lspci to look for:
#  09:00.0 3D controller: nVidia Corporation GF100 [M2070] (rev a3)

my $lspci_cmd = '/sbin/lspci';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'lspci_cmd' ) {
		$lspci_cmd = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $self = {};
	my ($fp,$gpu);
	
	$gpu = 'none';
	open( $fp, "$lspci_cmd |" );
	while( <$fp> ) {
		if( $_ =~ m/3D controller\:\s+(.*)/ ) {
			$gpu = lc( $1 );
			$gpu =~ s/[^a-z0-9 ]//g;
			$gpu =~ s/\s/\-/g;
			$gpu =~ s/\-corporation//;
		}
	}
	close( $fp );	
	
	$self->{'gpumodel'} = $gpu;
	
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
