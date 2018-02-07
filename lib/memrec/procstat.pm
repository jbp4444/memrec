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
# RCSID $Id: procstat.pm 562 2013-01-14 17:14:32Z jbp $

package procstat;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;
use wrapctr;

# for Linux 2.6.18, e.g., there are 8 fields in /proc/stat for cpu
# per cpu-line, in order:
#    cpu-number (cpu0, cpu1, etc.), then
#    user: normal processes executing in user mode
#    nice: niced processes executing in user mode
#    system: processes executing in kernel mode
#    idle: twiddling thumbs
#    iowait: waiting for I/O to complete
#    irq: servicing interrupts
#    softirq: servicing softirqs
# for Linux 2.6.24: (from 'man proc'):
#    there is a ninth column, guest, which is the time spent running 
#    a virtual  CPU  for  guest  operating systems under the control 
#    of the Linux kernel

sub prep {
}

sub new {
	my $class     = shift;
	my $self      = {};
	my ($e,$fp,$num_cpus);
	my @fld = ();

	open( $fp, '/proc/stat' )
	  or print STDERR "** Error: cannot open file [/proc/stat]\n";
	$num_cpus = 0;
	while (<$fp>) {
		if ( $_ =~ m/^(cpu\d*)/ ) {
			@fld             = split( /\s+/, $_ );
			$e               = $fld[0];
			$self->{"f1_$e"} = wrapctr->new( $fld[1] );
			$self->{"f2_$e"} = wrapctr->new( $fld[2] );
			$self->{"f3_$e"} = wrapctr->new( $fld[3] );
			$self->{"f4_$e"} = wrapctr->new( $fld[4] );
			$self->{"f5_$e"} = wrapctr->new( $fld[5] );
			$self->{"f6_$e"} = wrapctr->new( $fld[6] );
			$self->{"f7_$e"} = wrapctr->new( $fld[7] );
			$self->{"f8_$e"} = wrapctr->new( $fld[8] );
			if( scalar(@fld) > 10 ) {
				print "** Warning: only expected 9 fields in /proc/stat\n";
			}
			$num_cpus++;
		} else {
			last;
		}
	}

	$self->{'num_cpus'}  = $num_cpus;
	$self->{'fp'}        = $fp;
	$self->{'last_tstamp'} = 0;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $x, $y, $cp, $pp, $k, $kk, $txt, $dp );
	my $num_cpus = $self->{'num_cpus'};
	my $fp = $self->{'fp'};
	my $tstamp = $dref->{'tstamp'};
	my $last_tstamp = $self->{'last_tstamp'};
	my @fld = ();
	my @data = ();

	seek( $fp, 0, 0 );
	while (<$fp>) {
		if ( $_ =~ m/^(cpu\d*)/ ) {
			@fld             = split( /\s+/, $_ );
			$e               = $fld[0];
			$y = 0;
			$y += $self->{"f1_$e"}->update( $fld[1] );
			$y += $self->{"f2_$e"}->update( $fld[2] );
			$y += $self->{"f3_$e"}->update( $fld[3] );
			$x  = $self->{"f4_$e"}->update( $fld[4] ); # idle time
			$y += $x;
			$y += $self->{"f5_$e"}->update( $fld[5] );
			$y += $self->{"f6_$e"}->update( $fld[6] );
			$y += $self->{"f7_$e"}->update( $fld[7] );
			$y += $self->{"f8_$e"}->update( $fld[8] );
			if( $y == 0 ) {
				# MAJOR KLUDGE!!
				$y = 1;
			}
			if( $e eq 'cpu' ) {
				$dref->{'cpu'} = int( 100.0 - 100.0*$x / $y );
			} else {
				$k = $e;
				$k =~ s/cpu//;
				$data[$k] = int( 100.0 - 100.0*$x / $y );
			}
		}
		else {
			last;
		}
	}

	$dref->{'cpu_list'} = join( ',', @data );
	$self->{'last_tstamp'} = $tstamp;
	
	return (0);
}

sub delete {
	my $self = shift;
	
	close( $self->{'fp'} );
}

1;
