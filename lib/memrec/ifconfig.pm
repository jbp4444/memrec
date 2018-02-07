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
# RCSID $Id: ifconfig.pm 608 2013-04-23 19:41:39Z jbp $

package ifconfig;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

# eth0      Link encap:Ethernet  HWaddr 00:25:11:0A:3E:B3
#           inet addr:152.3.15.136  Bcast:152.3.15.255  Mask:255.255.255.0

my $ifconfig_cmd = '/sbin/ifconfig';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'ifconfig_cmd' ) {
		$ifconfig_cmd = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $self  = {};
	my ( $fp, $mac, $ip, $bcast, $mask, $flag );

	# new ifconfig output shows virbr0 networA
	# : make sure we only catch eth0 (or em1 on newer OS)
	$flag = 0;
	open( $fp, "$ifconfig_cmd |" );
	while (<$fp>) {
		chomp($_);
		if( $_ =~ m/^(eth0|em1)/ ) {
			$flag = 1;
		}
		if( $flag > 0 ) {
			if ( $_ =~ m/HWaddr (.*)$/ ) {
				$mac = $1;
				$flag++;
			}
			elsif ( $_ =~ m/inet addr\:(.*?)\s+Bcast\:(.*?)\s+Mask\:(.*)/ ) {
				$ip    = $1;
				$bcast = $2;
				$mask  = $3;
				$flag++;
			}
			if( $flag == 3 ) {
				$flag = 0;
				last;
			}
		}
	}
	close($fp);

	$mac =~ s/\s+//g;
	$ip =~ s/\s+//g;
	$bcast =~ s/\s+//g;
	$mask =~ s/\s+//g;

	$self->{'mac'}   = $mac;
	$self->{'ip'}    = $ip;
	$self->{'bcast'} = $bcast;
	$self->{'mask'}  = $mask;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);

	$dref->{'mac'}   = $self->{'mac'};
	$dref->{'ip'}    = $self->{'ip'};
	$dref->{'bcast'} = $self->{'bcast'};
	$dref->{'mask'}  = $self->{'mask'};

	return (0);
}

sub delete {

}

1;
