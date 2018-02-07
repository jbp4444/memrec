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

# TODO:
# --> virtual memory (total/used/free) ... VmallocTotal and VmallocUsed

package meminfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

sub prep {
	# modify local vars
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($fp);
	
	open( $fp, '/proc/meminfo' ) 
		or die "cannot open proc meminfo\n";

	$self->{'fp'} = $fp;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $fp   = $self->{'fp'};
	my ( $x, $m_total, $m_used, $m_free, $s_total, $s_used, $s_free, $v_total, $v_used, $v_free );
	$m_total = 1;
	$m_free  = 0;
	$s_total = 1;
	$s_free  = 0;

	seek( $fp, 0, 0 );
	
	while (<$fp>) {
		chomp($_);
		if ( $_ =~ m/MemTotal\:\s*(.*?)\s(\wB)$/ ) {
			$m_total = &convert_to_bytes( $1, $2 );
		}
		elsif ( $_ =~ m/MemFree\:\s*(.*?)\s(\wB)$/ ) {
			$m_free = &convert_to_bytes( $1, $2 );
		}
		elsif ( $_ =~ m/SwapTotal\:\s*(.*?)\s(\wB)$/ ) {
			$s_total = &convert_to_bytes( $1, $2 );
		}
		elsif ( $_ =~ m/SwapFree\:\s*(.*?)\s(\wB)$/ ) {
			$s_free = &convert_to_bytes( $1, $2 );
		}
		elsif ( $_ =~ m/VmallocTotal\:\s*(.*?)\s(\wB)$/ ) {
			$v_total = &convert_to_bytes( $1, $2 );
		}
		elsif ( $_ =~ m/VmallocUsed\:\s*(.*?)\s(\wB)$/ ) {
			$v_used = &convert_to_bytes( $1, $2 );
		}
	}    # last line in file
	$m_used = $m_total - $m_free;
	$s_used = $s_total - $s_free;
	$v_free = $v_total - $v_used;

	$dref->{'mem_total'}  = $m_total;
	$dref->{'mem_free'}   = $m_free;
	$dref->{'mem_used'}   = $m_used;
	$dref->{'swap_total'} = $s_total;
	$dref->{'swap_free'}  = $s_free;
	$dref->{'swap_used'}  = $s_used;
	$dref->{'virtual_total'} = $v_total;
	$dref->{'virtual_free'}  = $v_free;
	$dref->{'virtual_used'}  = $v_used;

	return (0);
}

sub delete {
	my $self = shift;
	
	close( $self->{'fp'} );
}

1;
