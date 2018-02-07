#!/usr/bin/perl
#
# (C) 2010-2011, John Pormann, Duke University
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
# RCSID $Id: netinfo.pm 107 2011-02-22 21:46:59Z jbp $

package newnetinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

use basesubs;
use wrapctr;

sub new {
	my $class = shift;
	my $self  = {};
	my ( $e, $num_eth, $fp );
	my @fld                 = ();
	my $last_bytes_in       = ();
	my $last_packets_in     = ();
	my $last_packeterrs_in  = ();
	my $last_bytes_out      = ();
	my $last_packets_out    = ();
	my $last_packeterrs_out = ();

	open( $fp, '/proc/net/dev' )
	  or print "** Error: cannot open file [/proc/net/dev]\n";
	$num_eth = 0;
	while (<$fp>) {
		if ( $_ =~ m/eth(\d)\:(.*)/ ) {
			$e                               = $1 + 0;
			@fld                             = split( /\s+/, $2 );
			$self->{"last_bytes_in_$e"}      = wrapctr->new( $fld[0] );
			$self->{"last_packets_in_$e"}    = wrapctr->new( $fld[1] );
			$self->{"last_packetserr_in_$e"} =
			  wrapctr->new( $fld[2] + $fld[3] + $fld[4] + $fld[5] );
			$self->{"last_bytes_out_$e"}      = wrapctr->new( $fld[8] );
			$self->{"last_packets_out_$e"}    = wrapctr->new( $fld[9] );
			$self->{"last_packeterrs_out_$e"} =
			  wrapctr->new( $fld[10] + $fld[11] + $fld[12] + $fld[13] );
			$num_eth++;
		}
	}

	$self->{'num_eth'} = $num_eth;
	$self->{'fp'}      = $fp;

	bless( $self, $class );
	return $self;

}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($e);
	my (
		$delta_bytes_in,    $delta_bytes_out,     $delta_packets_in,
		$delta_packets_out, $delta_packeterrs_in, $delta_packeterrs_out
	);
	my (
		$bytes_in_persec,    $bytes_out_persec,     $packets_in_persec,
		$packets_out_persec, $packeterrs_in_persec, $packeterrs_out_persec
	);
	my @fld         = ();
	my $num_eth     = $self->{'num_eth'};
	my $fp          = $self->{'fp'};
	my $tstamp      = $dref->{'tstamp'};
	my $last_tstamp = $dref->{'last_tstamp'};

	$delta_bytes_in       = 0;
	$delta_bytes_out      = 0;
	$delta_packets_in     = 0;
	$delta_packets_out    = 0;
	$delta_packeterrs_in  = 0;
	$delta_packeterrs_out = 0;

	seek( $fp, 0, 0 );

	while (<$fp>) {
		if ( $_ =~ m/eth(\d)\:(.*)/ ) {
			$e = $1 + 0;
			@fld = split( /\s+/, $2 );
			$delta_bytes_in   += $self->{"last_bytes_in_$e"}->update( $fld[0] );
			$delta_packets_in +=
			  $self->{"last_packets_in_$e"}->update( $fld[1] );
			$delta_packeterrs_in +=
			  $self->{"last_packetserr_in_$e"}
			  ->update( $fld[2] + $fld[3] + $fld[4] + $fld[5] );
			$delta_bytes_out += $self->{"last_bytes_out_$e"}->update( $fld[8] );
			$delta_packets_out +=
			  $self->{"last_packets_out_$e"}->update( $fld[9] );
			$delta_packeterrs_out +=
			  $self->{"last_packeterrs_out_$e"}
			  ->update( $fld[10] + $fld[11] + $fld[12] + $fld[13] );

		}
	}

	$bytes_in_persec       = $delta_bytes_in /       ( $tstamp - $last_tstamp );
	$packets_in_persec     = $delta_packets_in /     ( $tstamp - $last_tstamp );
	$packeterrs_in_persec  = $delta_packeterrs_in /  ( $tstamp - $last_tstamp );
	$bytes_out_persec      = $delta_bytes_out /      ( $tstamp - $last_tstamp );
	$packets_out_persec    = $delta_packets_out /    ( $tstamp - $last_tstamp );
	$packeterrs_out_persec = $delta_packeterrs_out / ( $tstamp - $last_tstamp );

	$dref->{'x_bytes_in'}       = &round00($bytes_in_persec);
	$dref->{'x_packets_in'}     = &round00($packets_in_persec);
	$dref->{'x_packeterrs_in'}  = &round00($packeterrs_in_persec);
	$dref->{'x_bytes_out'}      = &round00($bytes_out_persec);
	$dref->{'x_packets_out'}    = &round00($packets_out_persec);
	$dref->{'x_packeterrs_out'} = &round00($packeterrs_out_persec);

	return (0);
}

sub delete {
	my $self = shift;

	# could be nice and clean-up all the wrapctrs
	# for now, we'll let the garbage collector handle that

	close( $self->{'fp'} );
}

1;
