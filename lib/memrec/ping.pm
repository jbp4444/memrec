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
# RCSID $Id: ping.pm 592 2013-04-08 15:14:40Z jbp $

package ping;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $ping_cmd = '/bin/ping';
my $ping_args = '-c 1 -n';
my $ypmatch_cmd = '/bin/ypmatch';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'ping_cmd' ) {
		$ping_cmd = $val;
	} elsif( $key eq 'ping_args' ) {
		$ping_args = $val;
	} elsif( $key eq 'ping_ip' ) {
		$ping_ip = $val;
	} elsif( $key eq 'ypmatch_cmd' ) {
		$ypmatch_cmd = $val;
	}
	
	return;
}

sub new {
	my $class     = shift;
	my $ping_host = shift(@_);
	my $self      = {};            # allocate new hash for object
	my $ping_ip   = '127.0.0.1';
	my ($fp);

	if ( $ping_host =~ m/^\d/ ) {
		# assume ping_host is an IP-addr
		$ping_ip = $ping_host;
	}
	elsif( $ping_host =~ m/\w/ ) {
		open( $fp, "$ypmatch_cmd $ping_host hosts 2>&1 |" );
		$_ = <$fp>;

		# look for an IP-addr or else error
		if ( $_ =~ m/^(\d+\.\d+\.\d+\.\d+)/ ) {
			$ping_ip = $1;
		}
		else {
			$ping_ip = 'NO_PING';
		}
		close($fp);
	}

	$self->{'ping_ip'} = $ping_ip;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $ping_ip, $msec, $data, $fp );
	
	$ping_ip = $self->{'ping_ip'};
	
	open( $fp, "$ping_cmd $ping_args $ping_ip |" );
	$msec = -1;
	while (<$fp>) {
		if ( $_ =~ m/bytes from(.*?)time\=(.*)/ ) {
			$data = $2;
			if ( $data =~ m/ ms/i ) {
				$msec = $data + 0;

				# } elsif( $data =~ m/ us/ ) {
				#     should try to convert units!!
			}
			else {

				# assume msec
				$msec = $data + 0;
			}
		}
		elsif ( $_ =~ m/(.) packets transmitted, (.) received/ ) {
			if ( ( $1 + 0 ) != ( $2 + 0 ) ) {
				$msec = -1;
			}
		}
	}
	close($fp);

	$dref->{'ping'} = $msec;

	return( 0 );
}

sub delete {

}

1;

