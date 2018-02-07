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
# RCSID $Id: netinfo5.pm 591 2013-04-04 15:12:07Z jbp $

#
# this package assumes that it will be called at a fine granularity -- 1-min cycles
# and it will output:
#   5-min average gbps
#   max 1-min average gbps over the past 5-min

# NOTE: it's not entirely clear how well this works for multiple ethernet ports!!

# TODO: need to auto-locate the speed of each network port 
#     /sbin/ethtool eth0   ...    shows "Speed: 1000 Mb/s"

package netinfo5;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;
use wrapctr;

sub prep {
	# modify local vars
}

sub new {
	my $class = shift;
	my $self  = {};
	my ( $e, $num_eth, $fp, $x, $eth_speed );
	my @fld = ();

	# need to check lspci to find Eth driver .. to find 1G or 10G
	$eth_speed = 1;
	open( $fp, "/sbin/lspci |" )
	  or print STDERR "** Error: cannot run [/sbin/lspci]\n";
	while( <$fp> ) {
		if( $_ =~ m/Ethernet controller\:(.*)/ ) {
			$x = $1;
			if( $x =~ m/10 Gigabit/ ) {
				$eth_speed = 10;
			} else {
				$eth_speed = 1;
			}
		}
	}
	close( $fp );

	open( $fp, '/proc/net/dev' )
	  or print STDERR "** Error: cannot open file [/proc/net/dev]\n";
	$num_eth = 0;
	while (<$fp>) {
		if ( $_ =~ m/(eth|em)(\d)\:(.*)/ ) {
			$e                      = $2 + 0;
			@fld                    = split( /\s+/, $3 );
			$self->{"bytes_in_$e"}  = wrapctr->new( $fld[0] );
			$self->{"past_bytes_in_$e"}  = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
			$self->{"packets_in_$e"}  = wrapctr->new( $fld[1] );
			$self->{"past_packets_in_$e"}  = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
			$self->{"packeterrs_in_$e"}  = wrapctr->new( $fld[2]+$fld[3]+$fld[4]+$fld[5] );
			$self->{"past_packeterrs_in_$e"}  = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
			
			$self->{"bytes_out_$e"} = wrapctr->new( $fld[8] );
			$self->{"past_bytes_out_$e"} = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
			$self->{"packets_out_$e"} = wrapctr->new( $fld[9] );
			$self->{"past_packets_out_$e"} = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];
			$self->{"packeterrs_out_$e"} = wrapctr->new( $fld[10]+$fld[11]+$fld[12]+$fld[13] );
			$self->{"past_packeterrs_out_$e"} = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 ];

			$num_eth++;
		}
	}

	$self->{'num_eth'}     = $num_eth;
	$self->{'fp'}          = $fp;
	$self->{'last_tstamp'} = 0;
	$self->{'eth_speed'}   = $eth_speed;

	bless( $self, $class );
	return $self;

}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $e, $i, $pct25, $pct50, $pct75 );
	my ( $ttl_bytes_in, $ttl_bytes_out );
	my ( $max1m_bytes_in, $max1m_bytes_out );
	my ( $dbi, $dbo );
	my ( $past_bytes_in, $past_packets_in, $past_packeterrs_in );
	my ( $past_bytes_out, $past_packets_out, $past_packeterrs_out );
	my @fld         = ();
	my $num_eth     = $self->{'num_eth'};
	my $fp          = $self->{'fp'};
	my $tstamp      = $dref->{'tstamp'};
	my $last_tstamp = $self->{'last_tstamp'};

	if ( $last_tstamp == $tstamp ) {

		#
		# MAJOR KLUDGE to avoid div-by-zero
		$last_tstamp = $tstamp - 1;
	}

	seek( $fp, 0, 0 );

	while (<$fp>) {
		if ( $_ =~ m/(eth|em)(\d)\:(.*)/ ) {
			$e   = $2 + 0;
			@fld = split( /\s+/, $3 );

			$dbi           = $self->{"bytes_in_$e"}->update( $fld[0] );
			$past_bytes_in = $self->{"past_bytes_in_$e"};
			shift(@$past_bytes_in);
			push( @$past_bytes_in, $dbi );
			$self->{"past_bytes_in_$e"} = $past_bytes_in;
			
			$dbi           = $self->{"packets_in_$e"}->update( $fld[1] );
			$past_packets_in = $self->{"past_packets_in_$e"};
			shift(@$past_packets_in);
			push( @$past_packets_in, $dbi );
			$self->{"past_packets_in_$e"} = $past_packets_in;
			
			$dbi           = $self->{"packeterrs_in_$e"}->update( $fld[2]+$fld[3]+$fld[4]+$fld[5] );
			$past_packeterrs_in = $self->{"past_packeterrs_in_$e"};
			shift(@$past_packeterrs_in);
			push( @$past_packeterrs_in, $dbi );
			$self->{"past_packeterrs_in_$e"} = $past_packeterrs_in;

			$dbo            = $self->{"bytes_out_$e"}->update( $fld[8] );
			$past_bytes_out = $self->{"past_bytes_out_$e"};
			shift(@$past_bytes_out);
			push( @$past_bytes_out, $dbo );
			$self->{"past_bytes_out_$e"} = $past_bytes_out;

			$dbo            = $self->{"packets_out_$e"}->update( $fld[9] );
			$past_packets_out = $self->{"past_packets_out_$e"};
			shift(@$past_packets_out);
			push( @$past_packets_out, $dbo );
			$self->{"past_packets_out_$e"} = $past_packets_out;

			$dbo            = $self->{"packeterrs_out_$e"}->update( $fld[10]+$fld[11]+$fld[12]+$fld[13] );
			$past_packeterrs_out = $self->{"past_packeterrs_out_$e"};
			shift(@$past_packeterrs_out);
			push( @$past_packeterrs_out, $dbo );
			$self->{"past_packeterrs_out_$e"} = $past_packeterrs_out;
		}
	}

	# for the 10-min data, we need to scan over the 1-min data
	$ttl_bytes_in    = 0;
	$ttl_bytes_out   = 0;
	$max1m_bytes_in  = 0;
	$max1m_bytes_out = 0;
	$ttl_packets_in    = 0;
	$ttl_packets_out   = 0;
	$ttl_packeterrs_in    = 0;
	$ttl_packeterrs_out   = 0;

	# TODO: ASSUMES 1Gbps connections!!
	for ( $e = 0 ; $e < $num_eth ; $e++ ) {
		$past_bytes_in = $self->{"past_bytes_in_$e"};
		foreach $dbi (@$past_bytes_in) {
			$ttl_bytes_in += $dbi;
			if ( $dbi > $max1m_bytes_in ) {
				$max1m_bytes_in = $dbi;
			}
		}
		
		$past_bytes_out = $self->{"past_bytes_out_$e"};
		foreach $dbo (@$past_bytes_out) {
			$ttl_bytes_out += $dbo;
			if ( $dbo > $max1m_bytes_out ) {
				$max1m_bytes_out = $dbo;
			}
		}

		$past_packets_in = $self->{"past_packets_in_$e"};
		foreach $dbi (@$past_packets_in) {
			$ttl_packets_in += $dbi;
		}
		$past_packeterrs_in = $self->{"past_packeterrs_in_$e"};
		foreach $dbi (@$past_packeterrs_in) {
			$ttl_packeterrs_in += $dbi;
		}

		$past_packets_out = $self->{"past_packets_out_$e"};
		foreach $dbi (@$past_packets_out) {
			$ttl_packets_out += $dbi;
		}
		$past_packeterrs_out = $self->{"past_packeterrs_out_$e"};
		foreach $dbi (@$past_packeterrs_out) {
			$ttl_packeterrs_out += $dbi;
		}
	}
	
	$dref->{'bytes_in_max1m'} =
	  &round00( $max1m_bytes_in / ( $tstamp - $last_tstamp ) );
	$dref->{'bytes_out_max1m'} =
	  &round00( $max1m_bytes_out / ( $tstamp - $last_tstamp ) );
	$dref->{'bytes_in'}    =
	  &round00( $ttl_bytes_in / ( 5 * ( $tstamp - $last_tstamp ) ) );
	$dref->{'bytes_out'} =
	  &round00( $ttl_bytes_out / ( 5 * ( $tstamp - $last_tstamp ) ) );
	$dref->{'packets_in'}    =
	  &round00( $ttl_packets_in / ( 5 * ( $tstamp - $last_tstamp ) ) );
	$dref->{'packets_out'} =
	  &round00( $ttl_packets_out / ( 5 * ( $tstamp - $last_tstamp ) ) );
	$dref->{'packeterrs_in'}    =
	  &round00( $ttl_packeterrs_in / ( 5 * ( $tstamp - $last_tstamp ) ) );
	$dref->{'packeterrs_out'} =
	  &round00( $ttl_packeterrs_out / ( 5 * ( $tstamp - $last_tstamp ) ) );

	$self->{'last_tstamp'} = $tstamp;

	# new values for past_bytes_in/out were stored in the first loop

	return (0);
}

sub delete {
	my $self = shift;

	# could be nice and clean-up all the wrapctrs
	# for now, we'll let the garbage collector handle that

	close( $self->{'fp'} );
}

1;
