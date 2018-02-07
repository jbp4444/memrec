#!/usr/bin/perl
#
# (C) 2011, John Pormann, Duke University
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
# RCSID $Id: turbostat3.pm 338 2011-10-20 18:34:38Z jbp $

# TODO:
# - NOT FUNCTIONAL YET!

package turbostat3;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

use basesubs;
use wrapctr;

# uses 'dump_tstat -d' output
$dump_cmd = '/usr/sbin/dump_tstat';


sub read_msr {
	my $nc = shift(@_);
	my ( $fp, $c );
	my @fld = ();
	my $msrdata = {};

	open( $fp, "$dump_cmd -d |" );
	# skip one header line
	<$fp>;
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( ' ', $_ );
		$c = $fld[0];
		$msrdata->{"tsc $c"} = $fld[3];
		$msrdata->{"aperf $c"} = $fld[4];
		$msrdata->{"mperf $c"} = $fld[5];
	}
	close( $fp );

	return( $msrdata );
}

sub new {
	my $class = shift;
	my $cmd = shift( @_ );
	my $self  = {};
	my ( $num_cpus, $cpu_ven, $cpu_fam, $cpu_mod, $cpu_step );
	my ( $fp,       $msrref );

	if( $cmd =~ m/^\// ) {
		$dump_cmd = $cmd;
	}

	$num_cpus = 0;
	$cpu_ven  = 'generic-cpu';
	$cpu_fam  = 0;
	$cpu_mod  = 0;
	$cpu_step = 0;

	open( $fp, "/proc/cpuinfo" );
	while (<$fp>) {
		if ( $_ =~ m/^processor/i ) {
			$num_cpus++;
		}
		elsif ( $_ =~ m/^vendor_id\s+\:\s+(.*)/i ) {
			$cpu_ven = $1;
		}
		elsif ( $_ =~ m/^cpu family\s+\:(.*)/i ) {
			$cpu_fam = $1 + 0;
		}
		elsif ( $_ =~ m/^model\s+\:(.*)/i ) {
			$cpu_mod = $1 + 0;
		}
		elsif ( $_ =~ m/^stepping\s+\:(.*)/i ) {
			$cpu_step = $1 + 0;
		}
	}
	close($fp);

	$self->{'num_cpus'}     = $num_cpus;
	$self->{'cpu_vendor'}   = $cpu_ven;
	$self->{'cpu_family'}   = $cpu_fam;
	$self->{'cpu_model'}    = $cpu_mod;
	$self->{'cpu_stepping'} = $cpu_step;
	$self->{'last_tstamp'}  = time;

	# TODO: this is a big BIG HACK
	$self->{'ts_enable'} = 1;
	if ( $cpu_fam < 6 ) {

		# way too old a chip!
		$self->{'ts_enable'} = 0;
	}
	else {
		if ( $cpu_mod < 26 ) {
			$self->{'ts_enable'} = 0;
		}
	}

	if ( $self->{'ts_enable'} ) {
		$msrref = &read_msr($num_cpus);
		while( ($k,$v) = each %$msrref ) {
			$self->{$k} = wrapctr->new( $v );
		}
	}

	bless( $self, $class );
	return $self;

}

sub getdata {
	my $self     = shift;
	my $dref     = shift(@_);
	my $num_cpus = $self->{'num_cpus'};
	my $enable   = $self->{'ts_enable'};
	my $tstamp   = $dref->{'tstamp'};
	my $last_tstamp = $self->{'last_tstamp'};
	my ( $msrref, $k, $kk, $v, $x, $y, $delta, $avg );
	my @txt1 = ();
	my @txt2 = ();

	if ($enable) {
		$msrref = &read_msr($num_cpus);
		$delta = {};
		$avg = {};
		
		while ( ( $k, $v ) = each %$msrref ) {
			$x = $self->{$k}->update( $v );
			$delta->{$k} = $x;
			$kk = $k;
			
			# strip off the cpu-id number so we accumulate
			# average value for all cpus (sum divided by num_cpus)
			# TODO: we're assuming blank entries in various hashes are interpreted as 0
			$kk =~ s/\s\d+//;
			$avg->{$kk} += $x;
		}
		# finish up the average calculation
		while( ($k,$v) = each %$avg ) {
			$avg->{$k} = $v / $num_cpus;
		}

		$dref->{'tstat_c0pct'} = &round0( 100.0 * $avg->{'mperf'} / $avg->{'tsc'} );
		$dref->{'tstat_ghz'} = &round00( 1.0 * $avg->{'tsc'} / 1000000000 * $avg->{'aperf'} / $avg->{'mperf'} / ($tstamp - $last_tstamp) );

		for($k=0;$k<$num_cpus;$k++) {
			$x = &round0( 100.0 * $delta->{"mperf $k"} / $delta->{"tsc $k"} );
			$y = &round00( 1.0 * $delta->{"tsc $k"} / 1000000000 * $delta->{"aperf $k"} / 
					$delta->{"mperf $k"} / ($tstamp - $last_tstamp) );
			push( @txt1, $x );
			push( @txt2, $y );
		}
		$dref->{'tstat_clist'} = join( ',', @txt1 );
		$dref->{'tstat_glist'} = join( ',', @txt2 );

	} else {
		$dref->{'tstat_c0pct'} = 'n_a';
		$dref->{'tstat_ghz'}   = 'n_a';
		$dref->{'tstat_clist'} = 'n_a';
		$dref->{'tstat_glist'} = 'n_a';
	}
	
	$self->{'last_tstamp'} = $tstamp;

	return (0);
}

sub delete {
	my $self = shift;
}

1;
