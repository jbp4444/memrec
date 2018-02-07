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
# RCSID $Id: get_info.pl 605 2013-04-08 19:05:46Z jbp $

%host_data = ();
%hostjob_data = ();
%ps_data = ();

&qhost_info( \%host_data, \%hostjob_data );

&ps_info( \%ps_data );

print "ps data:\n";
foreach $key ( keys(%ps_data) ) {
	$val = $ps_data{$key};
	if( $val !~ m/^1\:/ ) {
		print "  $key : $val\n";
	}
}

exit;

print "host data:\n";
foreach $key ( keys(%host_data) ) {
	$val = $host_data{$key};
	print "  $key : $val\n";
}

print "host-job data:\n";
foreach $key ( keys(%hostjob_data) ) {
	$val = $hostjob_data{$key};
	print "  $key : $val\n";
}

# # # # # # # # # # # # # # # # # # # #
 # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # #

sub qhost_info {
	my $qhh_ref = shift( @_ );
	my $qhj_ref = shift( @_ );
	my ($fp,$host,$queue,$jobid,$x);
	@fld = ();
	
	open( $fp, "/usr/bin/qhost -q -j |" );
	<$fp>;  # skip header line
	<$fp>;  # skip header line
	<$fp>;  # skip header line
	$host = 'default';
	$queue = 'default';
	$jobid = 0;
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $fld[0] eq '' ) {
			shift( @fld );
		}
		
		if( $fld[0] =~ m/^high/ ) {
			$queue = 'high';
		} elsif( $fld[0] =~ m/^low/ ) {
			$queue = 'low';
		} elsif( $fld[0] =~ m/^SLAVE/ ) {
			# TODO: ??
			$qhj_ref->{$jobid} .= $host . ':';
		} elsif( $fld[0] =~ m/^\D/ ) {
			$host = $fld[0];
			$qhh_ref->{$host} = '';
		} elsif( $fld[0] =~ m/^\d/ ) {
			$jobid = $fld[0];
			if( exists($qhj_ref->{$jobid}) ) {
				$qhj_ref->{$jobid} .= $host . ':';
			} else {
				$qhj_ref->{$jobid} = $queue . '-' . $host . ':';			
			}
			$qhh_ref->{$host} .= $jobid . ':';
		}
	}
	close( $fp );
	
	return;	
}

sub walk_ps_info {
	my $ps_ref = shift( @_ );
	my $pid = shift( @_ );
	my ($sgejob,$ppid,$exe);

	($sgejob,$ppid,$exe) = split( ':', $ps_ref->{$pid} );

	if( $ppid <= 2 ) {
		# this is a root process .. stop
		$sgejob = 1;
	} elsif( $exe =~ m/sge_shepherd/ ) {
		$sgejob = $exe;
		$sgejob =~ s/(.*?)\-//;
	} else {
		$sgejob = &walk_ps_info( $ps_ref, $ppid );
	}

	return( $sgejob );
}

sub ps_info {
	my $ps_ref = shift( @_ );
	my ($fp,$pid,$ppid,$exe,$x,$sgejob);
	my @fld = ();
	
	open( $fp, "/bin/ps -Af n |" );
	<$fp>;  # skip header line
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $fld[0] eq '' ) {
			shift( @fld );
		}
		
		$pid  = $fld[1];
		$ppid = $fld[2];
		$exe  = $fld[8];

		$exe =~ s/^[\-\[]//;
		$exe =~ s/[\:]$//;

		$ps_ref->{$pid} = '0:' . $ppid . ':' . $exe;
	}
	close( $fp );

	# walk thru the pid/parent-pids
	foreach $pid ( keys(%$ps_ref) ) {
		($sgejob,$ppid,$exe) = split( ':', $ps_ref->{$pid} );
		$sgejob = &walk_ps_info( $ps_ref, $pid );

		$ps_ref->{$pid} = $sgejob . ':' . $ppid . ':' . $exe;
	}
	
	return;
}
