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
# RCSID $Id: netinfo.pm 606 2013-04-23 19:31:47Z jbp $

package netinfo2;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;
use wrapctr;


sub prep {
}

sub new {
	my $class = shift;
	my $self  = {};
	my ( $e, $i, $num_eth, $fp, $x, $eth_speed );
	my @fld = ();
	my %eth_list = ();

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
			$e                          = $2 + 0;
			@fld                        = split( /\s+/, $3 );
			for($i=0;$i<scalar(@fld);$i++) {
				$self->{"ctr_${e}_$i"} = wrapctr->new( $fld[$i] );
			}
			
			$eth_list{$e} = 1;
		}
	}

	$num_eth = 0;
	foreach $e ( keys(%eth_list) ) {
		$num_eth++;
	}
	
	$self->{'num_eth'} = $num_eth;
	$self->{'fp'}      = $fp;
	$self->{'last_tstamp'} = 0;
	$self->{'eth_speed'}   = $eth_speed;

	bless( $self, $class );
	return $self;

}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($e,$i);
	my (
		$delta_bytes_in,    $delta_bytes_out,     $delta_packets_in,
		$delta_packets_out, $delta_packeterrs_in, $delta_packeterrs_out
	);
	my @fld         = ();
	my @delta       = ();
	my $num_eth     = $self->{'num_eth'};
	my $fp          = $self->{'fp'};
	my $tstamp      = $dref->{'tstamp'};
	my $last_tstamp = $self->{'last_tstamp'};
	my $eth_speed   = $self->{'eth_speed'};
	my %eth_list = ();

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero
		$last_tstamp = $tstamp - 1;
	}

	seek( $fp, 0, 0 );

	while (<$fp>) {
		if ( $_ =~ m/(eth|em)(\d)\:\s*(.*)/ ) {
			$e = $2 + 0;
			@fld = split( /\s+/, $3 );

			@delta = ();
			for($i=0;$i<scalar(@fld);$i++) {
				$delta[$i] += $self->{"ctr_${e}_$i"}->update( $fld[$i] );
			}
			
			$eth_list{$e} = 1;

			$delta_bytes_in       = $delta[0];
			$delta_packets_in     = $delta[1];
			$delta_packeterrs_in  = $delta[2] + $delta[3] + $delta[4] + $delta[5];
			$delta_bytes_out      = $delta[8];
			$delta_packets_out    = $delta[9];
			$delta_packeterrs_out = $delta[10] + $delta[11] + $delta[12] + $delta[13];

			$dref->{"bytes_in_$e"} =
			&round00( $delta_bytes_in / ( $tstamp - $last_tstamp ) );
			$dref->{"packets_in_$e"} =
			&round00( $delta_packets_in / ( $tstamp - $last_tstamp ) );
			$dref->{"packeterrs_in_$e"} =
			&round00( $delta_packeterrs_in / ( $tstamp - $last_tstamp ) );
			$dref->{"bytes_out_$e"} =
			&round00( $delta_bytes_out / ( $tstamp - $last_tstamp ) );
			$dref->{"packets_out_$e"} =
			&round00( $delta_packets_out / ( $tstamp - $last_tstamp ) );
			$dref->{"packeterrs_out_$e"} =
			&round00( $delta_packeterrs_out / ( $tstamp - $last_tstamp ) );
		}
	}

	$dref->{"eth_speed"} = $eth_speed;
		  
	$self->{'last_tstamp'} = $tstamp;

	return (0);
}

sub delete {
	my $self = shift;

	# could be nice and clean-up all the wrapctrs
	# for now, we'll let the garbage collector handle that

	close( $self->{'fp'} );
}

1;
