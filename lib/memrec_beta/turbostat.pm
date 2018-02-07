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
# RCSID $Id: turbostat.pm 425 2012-08-15 14:13:45Z jbp $

# TODO:
# - NOT FUNCTIONAL YET!

package turbostat;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

use basesubs;
use wrapctr;

sub new {
	my $class = shift;
	my $cmd = shift(@_);
	my $self  = {};
	my ( $tscmd, $num_cpus, $c );
	my @fld = ();

	if( $cmd =~ m/^\// ) {
		$tscmd = $cmd;
	} else {
		$tscmd = '/usr/bin/turbostat';
	}
	
	open( $fp, "$tscmd /bin/sleep 1 2>&1 |" )
	  or print STDERR "** Error: cannot run turbostat command [$tscmd]\n";
	$num_cpus = 0;
	# skip 1 header lines
	<$fp>;
	# next line has cumulative cpu speed
	while (<$fp>) {
		if( $_ =~ m/^\s+(.*)/ ) {
			# cumulative info
		} elsif( $_ =~ m/^\d\s/ ) {
			# per-core info
			$num_cpus++;
		} else {
			# some extraneous lines do happen
		}	
	}
	close( $fp );
	
	open( $fp, "$tscmd -i $main::heartbeat 2>&1 |" );

	$self->{'tscmd'}       = $tscmd;
	$self->{'num_cpus'}    = $num_cpus;
	$self->{'fp'}          = $fp;

	bless( $self, $class );
	return $self;

}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $num_cpus    = $self->{'num_cpus'};
	my $fp          = $self->{'fp'};
	my ( $c, $x, $y, $flag, $bytes, $text );
	my @fld     = ();
	my @lines   = ();
	my $rfd     = '';
	my $timeout = 0.1;    # in sec
	my @spd_list = ();
	my @cst_list = ();

	$flag = 1;
	$rfd  = '';
	vec( $rfd, fileno($fp), 1 ) = 1;
	$flag = 0 unless select( $rfd, undef, undef, $timeout ) > 0;

	#
	# process all new data items
	$text = '';
	while ($flag) {
		$bytes = sysread( $fp, $x, 1024 );
		if ( $bytes > 0 ) {
			$text .= $x;
		} else {
			$flag = 0;
			last;
		}

		$rfd = '';
		vec( $rfd, fileno($fp), 1 ) = 1;
		$flag = 0 unless select( $rfd, undef, undef, $timeout ) > 0;
	}

	@lines = split( "\n", $text );
	foreach $y ( @lines ) {
		if( $y =~ m/^\s/ ) {
			# cumulative info
			@fld = split( /\s+/, $y );
			$dref->{'tstat_c0st'} = $fld[1];
			$dref->{'tstat_spd'} = $fld[2];
		} elsif( $y =~ m/^\d\s/ ) {
			# per-core info
			@fld = split( /\s+/, $y );
			$c = $fld[2] + 0;
			$cst_list[$c] = $fld[3];
			$spd_list[$c] = $fld[4];
		} else {
			# extraneous lines
		}	
	}
	# assumes max-speed of 4.0GHz
	$dref->{"tstat_spdl"} = join(',',@spd_list);
	$dref->{"tstat_c0stl"} = join(',',@cst_list);

	return (0);
}

sub delete {
	my $self = shift;

	# could be nice and clean-up all the wrapctrs
	# for now, we'll let the garbage collector handle that

	close( $self->{'fp'} );
}

1;
