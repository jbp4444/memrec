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
# RCSID $Id: diskstats.pm 628 2013-06-04 19:45:53Z jbp $

package diskstats;
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
	my ( $c, $n, $i, $num_partitions, $num_swap, $fp, $fp2 );
	my @fld             = ();

	open( $fp, '/proc/diskstats' )
	  or print STDERR "** Error: cannot open file [/proc/diskstats]\n";
	$c = 0;
	while (<$fp>) {
		if ( $_ =~ m/\s+([shd][dm][a-z\-]\d)\s+(.*)/ ) {
			$n                            = $1;
			@fld                          = split( /\s+/, $2 );
			for($i=0;$i<scalar(@fld);$i++) {
				$self->{"ctr_${n}_$i"} = wrapctr->new( $fld[$i] );
			}
			$self->{"is_swap_$n"}         = 0;
			$c++;
		}
	}
	$num_partitions = $c;

	# : now, what partitions are swap?
	$num_swap = 0;
	open( $fp2, '/proc/swaps' )
	  or print STDERR "** Error: cannot open file [/proc/swaps]\n";
	while (<$fp2>) {
		if ( $_ =~ m/\/([shd][dm][a-z\-]\d)\s+/ ) {
			$n = $1;
			$self->{"is_swap_$n"} = 1;
			$num_swap++;
		}
	}
	close($fp2);

	$self->{'num_partitions'} = $num_partitions;
	$self->{'num_swap'}       = $num_swap;
	$self->{'fp'}             = $fp;
	$self->{'last_tstamp'}    = 0;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self       = shift;
	my $dref       = shift(@_);
	my ( $c, $n, $i, $delta_num_rd, $delta_num_wr, $delta_sectors_rd,
		$delta_sectors_wr );
	my (
		$delta_sw_num_rd,     $delta_sw_num_wr,
		$delta_sw_sectors_rd, $delta_sw_sectors_wr
	);
	my @fld            = ();
	my @delta          = ();
	my $fp             = $self->{'fp'};
	my $tstamp         = $dref->{'tstamp'};
	my $last_tstamp    = $self->{'last_tstamp'};
	my $num_partitions = $self->{'num_partitions'};

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$last_tstamp = $tstamp - 1;
	}

	seek( $fp, 0, 0 );

	while (<$fp>) {
		if ( $_ =~ m/\s+([shd][dm][a-z\-]\d)\s+(.*)/ ) {
			$n = $1;
			@fld = split( /\s+/, $2 );
			for($i=0;$i<scalar(@fld);$i++) {
				$delta[$i] += $self->{"ctr_${n}_$i"}->update( $fld[$i] );
			}
		}
	}
	
	$delta_num_rd        = 0;
	$delta_sectors_rd    = 0;
	$delta_sw_num_rd     = 0;
	$delta_sw_sectors_rd = 0;
	$delta_num_wr        = 0;
	$delta_sectors_wr    = 0;
	$delta_sw_num_wr     = 0;
	$delta_sw_sectors_wr = 0;
	
	for($n=0;$n<$num_partitions;$n++) {
		if ( $self->{"is_swap_$n"} == 0 ) {
			$delta_num_rd     += $delta[0];
			$delta_sectors_rd += $delta[2];
			$delta_num_wr     += $delta[4];
			$delta_sectors_wr += $delta[6];
		}
		else {
			$delta_sw_num_rd     += $delta[0];
			$delta_sw_sectors_rd += $delta[2];
			$delta_sw_num_wr     += $delta[4];
			$delta_sw_sectors_wr += $delta[6];
		}
	}
		
	$dref->{'disk_rd'} = &round00( $delta_num_rd / ( $tstamp - $last_tstamp ) );
	$dref->{'disk_sec_rd'} =
	  &round00( $delta_sectors_rd / ( $tstamp - $last_tstamp ) );
	$dref->{'swap_rd'} =
	  &round00( $delta_sw_num_rd / ( $tstamp - $last_tstamp ) );
	$dref->{'swap_sec_rd'} =
	  &round00( $delta_sw_sectors_rd / ( $tstamp - $last_tstamp ) );
	$dref->{'disk_wr'} = &round00( $delta_num_wr / ( $tstamp - $last_tstamp ) );
	$dref->{'disk_sec_wr'} =
	  &round00( $delta_sectors_wr / ( $tstamp - $last_tstamp ) );
	$dref->{'swap_wr'} =
	  &round00( $delta_sw_num_wr / ( $tstamp - $last_tstamp ) );
	$dref->{'swap_sec_wr'} =
	  &round00( $delta_sw_sectors_wr / ( $tstamp - $last_tstamp ) );

	$self->{'last_num_rd'}     = $num_rd;
	$self->{'last_sectors_rd'} = $sectors_rd;
	$self->{'last_num_wr'}     = $num_wr;
	$self->{'last_sectors_wr'} = $sectors_wr;
	$self->{'last_tstamp'}     = $tstamp;

	return (0);
}

sub delete {
	my $self = shift;

	close( $self->{'fp'} );
}

1;
