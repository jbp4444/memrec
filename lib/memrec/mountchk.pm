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
# RCSID $Id: mountchk.pm 608 2013-04-23 19:41:39Z jbp $

package mountchk;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $ping_cmd = '/bin/ping';
my $ping_args = '-c 1 -n';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'ping_cmd' ) {
		$ping_cmd = $val;
	} elsif( $key eq 'ping_args' ) {
		$ping_args = $val;
	}
	
	return;
}

sub new {
	my $class   = shift;
	my $self    = {};              # allocate new hash for object
	my ( $fp, $m, $f );
	my %to_check = ();
	my %avail = ();
	my @fld = ();
	
	foreach $m ( @_ ) {
		$to_check{$m} = 1;
	}

	open( $fp, '/proc/mounts' )
	  or print STDERR "** Error: cannot open file [/proc/mounts]\n";
	while (<$fp>) {
		@fld = split( /\s/, $_ );
		$avail{$fld[1]} = $fld[0];
	}
	close($fp);

	foreach $m ( keys(%to_check) ) {
		$self->{"mnt_$m"} = $avail{$m};
	}	

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($k,$v,$vv,$fp,$data);
	
	while( ($k,$v) = each %$self ) {
		$vv = 0;
		if( $v =~ m/^\d/ ) {
			# this mount should be here, let's ping it
			$v =~ s/^(.*?)\:(.*)/$1/;  # v is now ip-addr
			open( $fp, "$ping_cmd $ping_args $v |" );
			while (<$fp>) {
				if ( $_ =~ m/(.) packets transmitted, (.) received/ ) {
					if ( ( $1 + 0 ) == ( $2 + 0 ) ) {
						$vv = 1;
					} else {
						$vv = -1;
					}
				}
			}
			close($fp);	
		}
		$k =~ s/\//_/g;
		$dref->{$k} = $vv;
	}

	return( 0 );
}

sub delete {

}

1;

