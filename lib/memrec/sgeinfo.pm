#!/usr/bin/perl
#
# (C) 2013, John Pormann, Duke University
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
# RCSID $Id: qstatinfo.pm 651 2013-06-25 13:54:29Z jbp $

# parse sge output to find simple queue status
#   Running/low-prio jobs
#   Running/high-prio jobs
#   Queued/low-prio jobs
#   Queued/high-prio jobs

package sgeinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $qstat_cmd = "/usr/bin/qstat -r -u '*'";
my $qstat_cmd2 = "/usr/bin/qstat -g c";
my $qhost_cmd = "/usr/bin/qhost";

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	my @fld = ();
	
	if( $key eq 'qstatcmd' ) {
		$qstat_cmd = $val;
	}

	return;	
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($fp,$flag);
	
	$flag = 0;
	open( $fp, "$qstat_cmd |" )
		or $flag = 1;
	if( $flag ) {
		print "* Error: cannot open qstat command [$qstat_cmd]\n";
	} else {
		close( $fp );
	}
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $q_lo, $q_hi, $r_lo, $r_hi );
	my ( $a_lo, $a_hi, $e_lo, $e_hi );
	my ( $q_or_r, $ncpus, $load );
	my ( $s_load, $s_avail, $s_error, $s_mach );
	my ( $fp, $fp2, $fp3 );
	my @fld = ();

	$q_lo = 0;
	$q_hi = 0;
	$r_lo = 0;
	$r_hi = 0;
	
	$s_error = 0;
	$s_load  = 0;
	$s_avail = 0;
	$s_mach  = 0;
	
	# we start by counting running jobs
	$q_or_r = 0;  
	
	open( $fp, "$qstat_cmd |" );
	$_ = <$fp>;  # skip two header lines
	$_ = <$fp>;
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $_ =~ m/^\d/ ) {
			# this is a job-id line ... includes num-cpus
			$ncpus = $fld[8];
			# and check if we've moved to queued jobs
			if( $fld[4] =~ m/qw/ ) {
				$q_or_r = 1;
			}
		} elsif( $_ =~ m/^\s+Hard Resources/ ) {
			if( $_ =~ m/highprio\=TRUE/ ) {
				# this is a high-prio job
				if( $q_or_r == 0 ) {
					$r_hi += $ncpus;
				} else {
					$q_hi += $ncpus;
				}
			} else {
				# this is a low-prio job
				if( $q_or_r == 0 ) {
					$r_lo += $ncpus;
				} else {
					$q_lo += $ncpus;
				}
			}
		}
	}
	close( $fp );

	# get the aggregate stats for the queues
	open( $fp2, "$qstat_cmd2 |" );
	$_ = <$fp2>;  # skip two header lines
	$_ = <$fp2>;
	while( <$fp2> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $_ =~ m/^high/ ) {
			$a_hi = $fld[6];
			$e_hi = $fld[7];
		} elsif( $_ =~ m/^low/ ) {
			$a_lo = $fld[6];
			$e_lo = $fld[7];
		} else {
			# skip any other queues (like maint.q)
		}
	}
	close( $fp2 );
	
	# get the aggregate stats for the system
	open( $fp3, "$qhost_cmd |" );
	$_ = <$fp3>;  # skip three header lines
	$_ = <$fp3>;
	$_ = <$fp3>;
	while( <$fp3> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		$ncpus = $fld[2];
		$load  = $fld[3];
		$s_mach++;
		if( $load =~ '-' ) {
			# this host is having issues
			$s_error += $ncpus;
		} else {
			$s_avail += $ncpus;
			if( $load <= $ncpus ) {
				$s_load += $load;	
			} else {
				$s_load += $ncpus;
			}
		}
	}
	close( $fp3 );

	$dref->{'sge_hi_q'} = $q_hi;
	$dref->{'sge_lo_q'} = $q_lo;
	$dref->{'sge_hi_r'} = $r_hi;
	$dref->{'sge_lo_r'} = $r_lo;
	$dref->{'sge_hi_a'} = $a_hi;
	$dref->{'sge_lo_a'} = $a_lo;
	$dref->{'sge_hi_e'} = $e_hi;
	$dref->{'sge_lo_e'} = $e_lo;
	$dref->{'sge_sys_error'} = $s_error;
	$dref->{'sge_sys_load'}  = $s_load;
	$dref->{'sge_sys_avail'} = $s_avail;
	$dref->{'sge_sys_mach'}  = $s_mach;
	
	return( 0 );
}

sub delete {

}

1;
