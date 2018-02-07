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
# RCSID $Id: meminfo.pm 421 2012-05-21 13:58:30Z jbp $


package vmstat;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $vmstat_cmd = '/usr/bin/vmstat';

sub prep {
	# modify local vars
}

sub new {
	my $class = shift;
	my $self  = {};
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $fp, $x, $m_total, $m_used, $m_free, $s_total, $s_used, $s_free, $v_total, $v_used, $v_free );
	$m_total = 1;
	$m_free  = 0;
	$s_total = 1;
	$s_free  = 0;

	open( $fp, "$vmstat_cmd -s |" );

	while (<$fp>) {
		chomp($_);
		if ( $_ =~ m/(.*?)\stotal memory$/ ) {
			$m_total = $1 + 0;
		}
		elsif ( $_ =~ m/(.*?)\sused memory$/ ) {
			$m_used = $1 + 0;
		}
		elsif ( $_ =~ m/(.*?)\sfree memory$/ ) {
			$m_free = $1 + 0;
		}
		elsif ( $_ =~ m/(.*?)\stotal swap$/ ) {
			$s_total = $1 + 0;
		}
		elsif ( $_ =~ m/(.*?)\sused swap$/ ) {
			$s_used = $1 + 0;
		}
		elsif ( $_ =~ m/(.*?)\sfree swap$/ ) {
			$s_free = $1 + 0;
		}
	}
	close( $fp );


	$dref->{'mem_total'}  = $m_total;
	$dref->{'mem_free'}   = $m_free;
	$dref->{'mem_used'}   = $m_used;
	$dref->{'swap_total'} = $s_total;
	$dref->{'swap_free'}  = $s_free;
	$dref->{'swap_used'}  = $s_used;

	return (0);
}

sub delete {
	my $self = shift;
	
}

1;
