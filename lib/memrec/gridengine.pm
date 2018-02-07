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
# RCSID $Id: gridengine.pm 617 2013-04-29 17:48:49Z jbp $

package gridengine;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $hostname = 'default';
my $basedir = '/var/spool/gridengine';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );

	if( lc($key) eq 'basedir' ) {
		$basedir = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($dp);
	
	if( $hostname eq 'default' ) {
		$hostname = `hostname`;
		chomp( $hostname );
		$hostname =~ s/(.*?)\.(.*)/$1/;
	}

	opendir( $dp, "$basedir/$hostname/active_jobs" )
	  or print STDERR "** Error: cannot open file [$basedir/$hostname/active_jobs]\n";
	closedir($dp);

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $count, $count_lo, $count_hi, $x, $dp, $fp );
	my @list = ();
	my @joblist_lo = ();
	my @joblist_hi = ();
	
	opendir( $dp, "$basedir/$hostname/active_jobs" );
	@list = grep { /^\d/ } readdir($dp);
	closedir($dp);

	$count = 0;
	$count_lo = 0;
	$count_hi = 0;

	foreach $l (@list) {
		open( $fp, "$basedir/$hostname/active_jobs/$l/environment" );
		while( <$fp> ) {
			chomp( $_ );
			if( $_ =~ m/^QUEUE\=(.*)/ ) {
				$x = $1;
				if( $x =~ m/^low/ ) {
					push( @joblist_lo, $l );
					$count_lo++;
				} elsif( $x =~ m/^high/ ) {
					push( @joblist_hi, $l );
					$count_hi++;
				}
				last;
			}
		}
		close($fp);
		
		$count++;
	}

	$dref->{'num_jobs'} = $count;
	$dref->{'num_lowprio'} = $count_lo;
	$dref->{'num_highprio'} = $count_hi;

	if( scalar(@joblist_lo) == 0 ) {
		push( @joblist_lo, 'n_a' );
	}
	if( scalar(@joblist_hi) == 0 ) {
		push( @joblist_hi, 'n_a' );
	}
	$dref->{'joblist_lo'} = join( ',', @joblist_lo );
	$dref->{'joblist_hi'} = join( ',', @joblist_hi );

	return( 0 );
}

sub delete {

}

1;
