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
# RCSID $Id: qstatinfo.pm 651 2013-06-25 13:54:29Z jbp $

package qstatinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $qstat_cmd = "/usr/bin/qstat -f -u '*'";

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
	my ( $fp, $host, $queue, $jid, $jname, $uid );
	my ( $state, $start_time, $nslots );
	my ( $k, $v, $hlist, $trange );
	my %jobinfo = ();
	my @fld = ();

	$host = 'default';
	$queue = 'default';
	$jid  = 0;
	$jname = 'default';
	$uid  = 'default';
	$state = '-';
	$start_time = "default";
	$nslots = 0;
	
	open( $fp, "$qstat_cmd |" );
	while( <$fp> ) {
		chomp( $_ );
		if( $_ =~ m/^\-\-\-/ ) {
			# separator line, skip
			next;
		} elsif( $_ =~ m/^queuename/ ) {
			# header line, skip
			next;
		} elsif( $_ =~ m/^\#\#\#/ ) {
			# comment line, skip
			next;
		} elsif( $_ =~ m/^\s+\-\s+PENDING JOBS/ ) {
			# separator line, skip
			$host = '';
			next;
		} elsif( $_ eq '' ) {
			# blank line, skip
			next;
		} elsif( $_ =~ m/^[[:alpha:]]/ ) {
			# queue identifier
			@fld = split( /[ .\@]/, $_ );
			$queue = $fld[0];
			$host = $fld[2];
			#print "queue = [$queue][$host]  ($_)\n";
		} elsif( $_ =~ m/^\d/ ) {
			# job info line
			@fld = split( /\s+/, $_ );
			$jid   = $fld[0];
			$jname = $fld[2];
			$uid   = $fld[3];
			$state = $fld[4];
			#$start_time = $fld[5] . '-' . $fld[6];
			$nslots = $fld[7];
			$trange = 'undefined,undefined,undefined';
			if( $state =~ m/q/ ) {
				# job is queued, we should have whole task range
				if( $fld[8] eq '' ) {
					$tid = '';
				} else {
					$fld[8] =~ m/(.*?)\-(.*?)\:(.*)/;
					$trange = $1 . ',' . $2 . ',' . $3;
				}
			} else {
				# job is running ... only task-ID can be found (easily)
				if( $fld[8] eq '' ) {
					$tid = '';
				} else {
					$tid   = '.' . $fld[8];
				}
			}
			if( exists($jobinfo{"$jid$tid"}) ) {
				$hlist = $jobinfo{"$jid$tid"}->{hostlist};
				$hlist .= ',' . $host;
				$nslots += $jobinfo{"$jid$tid"}->{nslots};
				$jobinfo{"$jid$tid"} = { queue=>$queue, hostlist=>$hlist, nslots=>$nslots,
					job_name=>$jname, user=>$uid, state=>$state, task_range=>$trange };
			} else {
				$jobinfo{"$jid$tid"} = { queue=>$queue, hostlist=>$host, nslots=>$nslots,
					job_name=>$jname, user=>$uid, state=>$state, task_range=>$trange };
			}
		}
	}
	close( $fp );

	while( ($k,$v) = each %jobinfo ) {
		if( $k =~ m/(.*?)\.(.*)/ ) {
			$jid = $1;
			$tid = $2;
		} else {
			$jid = $k;
			$tid = 'undefined';
		}
		$queue  = $v->{queue};
		$jname = $v->{job_name};
		$uid   = $v->{user};
		$state = $v->{state};
		$nslots = $v->{nslots};
		$hlist = $v->{hostlist};
		$trange = $v->{task_range};
		$dref->{$k} = "action=jobstatus job_id=$jid task_id=$tid hostlist=$hlist "
			. "queue=$queue state=$state nslots=$nslots task_range=$trange "
			. "user=$uid job_name=$jname";
	}
	
	return( 0 );
}

sub delete {

}

1;
