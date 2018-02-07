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
# RCSID $Id: sgelog.pm 646 2013-06-24 18:52:59Z jbp $

package sgelog;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $sgelog_dir = '/var/spool/gridengine/';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	my @fld = ();
	
	if( $key eq 'sgelogdir' ) {
		$sgelog_dir = $val;
	}

	return;	
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($fp,$d,$mydir,$myfile);
	my @list = ();

	$mydir = '/';
	
	opendir( $fp, $sgelog_dir )
		|| die "* Error: cannot open dir [$sgelog_dir] e=($!)\n";
	@list = readdir($fp);
	foreach $d ( @list ) {
		if( $d =~ m/^\./ ) {
			# skip any dot directories
		} elsif( $d =~ m/^default/ ) {
			# skip the default directory
		} else {
			# assume there is only one non-default directory
			$mydir = $d;
			last;
		}
	}
	closedir( $fp );
	
	$myfile = $sgelog_dir . '/' . $mydir . '/messages';
	$myfile =~ s/\/\//\//g;

	open( $fp, $myfile );
	
	$self->{'myfile'} = $myfile;
	$self->{'myfp'} = $fp;
	$self->{'lasttime'} = '';
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $myfile = $self->{'myfile'};
	my $lasttime = $self->{'lasttime'};
	my $fp = $self->{'myfp'};
	my ( $flag, $k, $v );
	my @fld = ();

	if( $lasttime eq '' ) {
		$flag = 1;
	} else {
		$flag = 0;
	}

	seek( $fp, 0, 0 );
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\|/, $_ );
		if( $flag == 0 ) {
			if( $fld[0] eq $lasttime ) {
				$flag = 1;
			}
		} else {
			# output everything
			$k = $fld[0];
			$v = join( ' ', ($fld[3],$fld[4]) );
			$dref->{$k} = $v;
			$lasttime = $fld[0];
		}
	}

	$self->{'lasttime'} = $lasttime;

	return( 0 );
}

sub delete {
	my $self = shift( @_ );
	my $fp = $self->{'myfp'};

	close( $fp );

	return;
}

1;
