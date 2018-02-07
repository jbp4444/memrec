#!/usr/bin/perl
#
# (C) 2012, John Pormann, Duke University
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
# RCSID $Id: condorinfo.pm 669 2013-09-19 20:47:04Z jbp $

package condorinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $cstat_cmd = '/usr/bin/condor_status -xml';
my $cqueue_cmd = '/usr/bin/condor_q';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	my @fld = ();
	
	if( $key eq 'condorstatcmd' ) {
		$cstat_cmd = $val;
	}

	return;	
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($fp,$flag);
	
	$flag = 0;
	open( $fp, "$cstat_cmd |" )
		or $flag = 1;
	if( $flag ) {
		print "* Error: cannot open qstat command [$cstat_cmd]\n";
	} else {
		close( $fp );
	}
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $fp, $x, $total_cpus, $total_claimed, $total_unclaimed, $total_owner );
	my ( $total_machines, $q_jobs, $r_jobs, $s_jobs );
	my %mlist = ();
	my @fld = ();
	
	$total_cpus = 0;
	$total_claimed = 0;
	$total_unclaimed = 0;
	$total_owner = 0;
	$total_machines = 0;
	$q_jobs = 0;
	$r_jobs = 0;

	# assume each entry is one cpu-slot
	#      <a n="State"><s>Unclaimed</s></a>	
	open( $fp, "$cstat_cmd |" );
	while( <$fp> ) {
		chomp( $_ );
		if( $_ =~ /\"State\"(.*)/ ) {
			$x = $1;
			$total_cpus++;
			if( $x =~ m/Unclaimed/ ) {
				$total_unclaimed++;
			} elsif( $x =~ m/Owner/ ) {
				$total_owner++;
			} elsif( $x =~ m/Claimed/ ) {
				$total_claimed++;
			} else {
				# unknown state-type
				print "unknown state [$_]\n";
			}
		} elsif( $_ =~ m/\"Machine\"(.*)/ ) {
			$_ =~ m/\<s\>(.*?)\</;
			$x = $1;
			$mlist{$x} = 1;
		}	
	}
	close( $fp );	
	$total_machines = scalar( keys(%mlist) );

	# jobs in queue
	### 143 jobs; 0 completed, 0 removed, 0 idle, 0 running, 143 held, 0 suspended
	
	open( $fp, "$cqueue_cmd |" );
	while( <$fp> ) {
		chomp( $_ );
		if( $_ =~ /^(\d+) jobs/ ) {
			@fld = split( /\s+/, $_ );
			$r_jobs = $fld[8];
			$q_jobs = $fld[10];
			$s_jobs = $fld[12];
			last;
		}	
	}
	close( $fp );

	$dref->{'condor_machines'}  = $total_machines;
	$dref->{'condor_cpus'}      = $total_cpus;
	$dref->{'condor_claimed'}   = $total_claimed;
	$dref->{'condor_unclaimed'} = $total_unclaimed;
	$dref->{'condor_owner'}     = $total_owner;
	$dref->{'condor_jobs_r'}    = $r_jobs;
	$dref->{'condor_jobs_q'}    = $q_jobs;
	$dref->{'condor_jobs_s'}    = $s_jobs;
	
	return( 0 );
}

sub delete {

}

1;
