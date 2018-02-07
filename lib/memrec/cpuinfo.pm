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
# RCSID $Id: cpuinfo.pm 608 2013-04-23 19:41:39Z jbp $

package cpuinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $show_cpuflags = 0;
my $show_numproc = 0;

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'cpuflags' ) {
		$show_cpuflags = &convert_to_yesno( $val );
	} elsif( $key eq 'show_numproc' ) {
		$show_numproc = &convert_to_yesno( $val );
	}
	
	return;
}

sub new {
	my $class   = shift;
	my $self    = {};              # allocate new hash for object
	my $mhz     = 0.0;
	my $model   = 'generic-cpu';
	my $modeln  = '0.0.0';
	my ( $cpufam, $cpumod, $cpustep, $fp, $num_proc, $cflags, $i, $j );
	my @phys_cores = ();
	my @phys_sockets = ();

	$num_proc = 0;
	$cflags = '';
	
	open( $fp, '/proc/cpuinfo' )
	  or print STDERR "** Error: cannot open file [/proc/cpuinfo]\n";
	while (<$fp>) {
		if ( $_ =~ m/^cpu mhz/i ) {
			$mhz = $_;
			$mhz =~ s/cpu mhz\s*\:\s*(.*)/$1/i;

			# round mhz to nearest 50mhz
			$mhz = 50 * int( ( $mhz + 25 ) / 50 );
		}
		elsif ( $_ =~ m/^model\s+name/i ) {
			chomp($_);
			$model = lc($_);
			$model =~ s/model\s+name\s*\:\s*(.*)/$1/i;
			$model =~ s/\(r\)//g;
			$model =~ s/\(tm\)//g;
			$model =~ s/cpu//;
			$model =~ s/processor//;
			$model =~ s/\@.*//;
			$model =~ s/\w+\-core//;
			$model =~ s/\d+\.\d+ghz//;
			$model =~ s/^\s+//;
			$model =~ s/\s+$//;
			$model =~ s/\s+/-/g;
		}
		elsif ( $_ =~ m/^cpu\s+family/i ) {
			$cpufam = $_;
			$cpufam =~ s/cpu\s+family\s*\:\s*(.*)/$1/i;
			$cpufam += 0;
		}
		elsif ( $_ =~ m/^model/i ) {
			$cpumod = $_;
			$cpumod =~ s/model\s*\:\s*(.*)/$1/i;
			$cpumod += 0;
		}
		elsif ( $_ =~ m/^stepping/i ) {
			$cpustep = $_;
			$cpustep =~ s/stepping\s*\:\s*(.*)/$1/i;
			$cpustep += 0;
		}
		elsif ( $_ =~ m/^flags/i ) {
			$cflags = $_;
			$cflags =~ s/flags\s*\:\s*(.*)/$1/i;
			$cflags =~ s/\s+/,/g;
		}
		elsif ( $_ =~ m/^processor/i ) {
			$num_proc++;
		}
		elsif ( $_ =~ m/^core id\s*\:\s*(.*)/i ) {
			$i = $1 + 0;
			$phys_cores[$i] = 1;
		}
		elsif ( $_ =~ m/^physical id\s*\:\s*(.*)/i ) {
			$i = $1 + 0;
			$phys_sockets[$i] = 1;
		}
	}
	close($fp);
	$modeln = $cpufam . '.' . $cpumod . '.' . $cpustep;
	
	# cpu config:  physical number of sockets and physical number of cores (vs. hyperthreading)
	$i = scalar( @phys_sockets );
	$j = scalar( @phys_cores );
	$self->{'phys_sockets'} = $i;
	$self->{'phys_cores'} = $i * $j;
	if( ($i*$j) < $num_proc ) {
		$self->{'ht_enabled'} = 1;
	} else {
		$self->{'ht_enabled'} = 0;
	}
	
	$self->{'mhz'}     = $mhz;
	$self->{'cpumodel'}   = $model;
	$self->{'cpumodeln'}  = $modeln;
	if( $show_numproc ) {
		$self->{'num_proc'} = $num_proc;
	}
	if( $show_cpuflags ) {
		$self->{'cpuflags'} = $cflags;
	}

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($k,$v);
	
	while( ($k,$v) = each %$self ) {
		$dref->{$k} = $v;
	}

	return( 0 );
}

sub delete {

}

1;

