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
# RCSID $Id: txtfile.pm 585 2013-04-01 16:47:00Z jbp $

package txtfile;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $txt_filename = '/usr/local/etc/addl_vals.txt';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );

	if( lc($key) eq 'file' ) {
		$txt_filename = $val;
	}

	return;
}

sub new {
	my $class = shift;
	my $fname = shift(@_);
	my ( $k, $v, $flag, $fp );
	my $self = {};
	my $data = {};

	if ( $fname ~= m/^\// ) {
		# assume valid filename
	} else {
		$fname = $txt_filename;
	}

	$flag = 0;
	open( $fp, $fname ) or $flag = 1;
	if ($flag) {
		print STDERR "** Error: cannot open file [$fname]\n";
	}
	else {
		while (<$fp>) {
			chomp($_);
			if ( $_ =~ m/^(.*?)\s*[=:]\s*(.*)/i ) {
				$k = $1;
				$v = $2;
				$k =~ s/\s/_/g;
				$v =~ s/\s/_/g;
				$data->{$k} = $v;
			}
		}

	}

	$self->{'data'} = $data;

	bless( $self, $class );
	return ($self);
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $data = $self->{'data'};
	my ($k, $v );
	
	while( ($k,$v) = each %$data ) {
		$dref->{$k} = $v;
	}


	return (0);
}

sub delete {

}

1;

