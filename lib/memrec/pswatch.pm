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
# RCSID $Id: pswatch.pm 599 2013-04-08 15:46:37Z jbp $

package pswatch;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $full_path = 0;
my %skip_uids = ();
my $do_count = 1;

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	my @fld = ();
	
	if( $key eq 'full_path' ) {
		$full_path = &convert_to_yesno($val);
	} elsif( $key eq 'do_count' ) {
		$do_count = &convert_to_yesno($val);
	} elsif( $key eq 'skip_uid' ) {
		if( $val =~ m/\D/ ) {
			@fld = getpwnam( $val );
			$val = $fld[2];
		}
		$skip_uids{$val} = 1;
	}

	return;	
}

sub new {
	my $class = shift;
	my $self  = {};

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $fp, $exe, $uid, $k, $v );
	my %list = ();
	my @fld = ();

	open( $fp, "/bin/ps -Af n |" );
	<$fp>;  # skip 1 header line
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $fld[0] eq '' ) {
			shift( @fld );
		}
		$uid = $fld[0];
		$exe = $fld[8];

		if( exists($skip_uids{$uid}) ) {
			next;
		}

		$exe =~ s/^[\-\[]//;
		$exe =~ s/[\:]$//;

		if( $full_path ) {
			$list{$exe}++;
		} else {
			$exe =~ s/\/(.*)\///;
			$list{$exe}++;
		}		
		
	}

	while( ($k,$v) = each(%list) ) {
		if( $do_count ) {
			$dref->{$k} = $v;
		} else {
			$dref->{$k} = '';
		}
	}

	return( 0 );
}

sub delete {

}

1;
