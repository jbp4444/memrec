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
# RCSID $Id: pidmem.pm 526 2012-09-05 14:51:45Z jbp $

package pidmem;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

sub prep {
}

sub new {
	my $class = shift;
	my $pid = shift( @_ );
	my $self = {};
	my ($fp,$i,$flag);
	
	$flag = 1;
	for($i=0;$i<10;$i++) {
		$flag = 0;
		open( $fp, "/proc/$pid/status" ) or $flag = 1;
		if( $flag == 1 ) {
			print "pid file: error [$!]\n";
			sleep( 1 );
		} else {
			$flag = 0;
			last;
		}
			
	}
	if( $flag == 1 ) {
		die "cannot open pid status file\n";
	}
	
	$self->{'pid'} = $pid;
	$self->{'fp'} = $fp;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $pid = $self->{'pid'};
	my ($x,$y,$b,$r,$fp);

	$fp = $self->{'fp'};
	seek( $fp, 0, 0 );

	while( <$fp> ) {
		chomp( $_ );
		$_ =~ m/(.*?)\:\s+(.*)/;
		$x = $1;
		$y = $2;
		if( ($x =~ m/^Vm/) or ($x =~ m/^StaStk/) or ($x =~ m/Brk/) ) {
			$y =~ m/\s*(.*?)\s(.*)/;
			$b = &convert_to_bytes( $1, $2 );
			$dref->{$x} += $b;
		} elsif( $x =~ m/^SleepAVG/ ) {
			$b = $y + 0;
			$dref->{$x} += $b;
		} elsif( $x =~ m/^Threads/ ) {
			$b = $y + 0;
			$dref->{$x} += $b;
		}
	}

	return( 0 );
}

sub delete {
	my $self = shift;
	
	close( $self->{'fp'} );
}

1;
