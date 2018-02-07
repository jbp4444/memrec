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
# RCSID $Id: linpack.pm 585 2013-04-01 16:47:00Z jbp $

package linpack;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $linpack_1_cmd = 'cd /opt/apps/intel/versions/20121002/mkl/benchmarks/linpack ; OMP_NUM_THREADS=1 ; export OMP_NUM_THREADS ; ./xlinpack_xeon64 lininput_sge1';
my $linpack_N_cmd = 'cd /opt/apps/intel/versions/20121002/mkl/benchmarks/linpack ; ./xlinpack_xeon64 lininput_sgeN';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( lc($key) eq 'linpack_1' ) {
		$linpack_1_cmd = $val;
	} elsif( lc($key) eq 'linpack_N' ) {
		$linpack_N_cmd = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $self = {};
	my ($fp,$kflops,$m_kflops,$mult,$flag);
	my @fld = ();
	
	open( $fp, "$linpack_1_cmd 2>&1 |" )
		or print "** Error: cannot open pipe to linpack cmd\n";
	$flag = 0;
	$mult = 1;
	$kflops = -1;
	while( <$fp> ) {
		if( $_ =~ m/Performance Summary\s+\((.)/ ) {
			if( $1 =~ m/k/i ) {
				$mult = 1;
			} elsif( $1 =~ m/g/i ) {
				$mult = 1024;
			}
			$flag = 1;
		}
		if( $flag == 1 ) {
			if( $_ =~ m/^\d/ ) {
				# field-3 is average
				# field-4 is max
				@fld = split( /\s+/, $_ );
				$kflops = ( $fld[4] + 0 ) * $mult;
			}
		}
	}
	close( $fp );
	
	open( $fp, "$linpack_N_cmd 2>&1 |" )
		or print "** Error: cannot open pipe to linpack cmd\n";
	$flag = 0;
	$mult = 1;
	$m_kflops = -1;
	while( <$fp> ) {
		if( $_ =~ m/Performance Summary\s+\((.)/ ) {
			if( $1 =~ m/k/i ) {
				$mult = 1;
			} elsif( $1 =~ m/g/i ) {
				$mult = 1024;
			}
			$flag = 1;
		}
		if( $flag == 1 ) {
			if( $_ =~ m/^\d/ ) {
				# field-3 is average
				# field-4 is max
				@fld = split( /\s+/, $_ );
				$m_kflops = ( $fld[4] + 0 ) * $mult;
			}
		}
	}
	close( $fp );
	
	$self->{'cpu_kflops'} = &round0( $kflops );
	$self->{'total_kflops'} = &round0( $m_kflops );
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);

	$dref->{'cpu_kflops'} = $self->{'cpu_kflops'};
	$dref->{'total_kflops'} = $self->{'total_kflops'};
	
	return( 0 );	
}

sub delete {
	
}

1;
