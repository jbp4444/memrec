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
# RCSID $Id: df.pm 608 2013-04-23 19:41:39Z jbp $

package df;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $df_cmd = '/bin/df';
my $df_args = '-kP';

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( $key eq 'df_cmd' ) {
		$df_cmd = $val;
	} elsif( $key eq 'df_args' ) {
		$df_args = $val;
	}
	
	return;
}

sub new {
	my $class = shift;
	my $name  = shift(@_);
	my $dir   = shift(@_);
	my $self  = {};          # allocate new hash for object

	if( $dir !~ m/^\// ) {
		$dir = '/';
	}

	if ( not -e $dir ) {
		print STDERR "** Error: no $dir directory exists\n";
	}
	if ( not -d $dir ) {
		print STDERR "** Error: $dir is not a directory\n";
	}
	$self->{'name'} = $name;
	$self->{'dir'} = $dir;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my @list = ();
	my ($name,$dir,$dffree,$fp);

	$name = $self->{'name'};
	$dir = $self->{'dir'};
	open( $fp, "$df_cmd $df_args $dir 2>&1 |" );

	# skip first line (header)
	<$fp>;
	$_ = <$fp>;
	close($fp);
	@list = split( /\s+/, $_ );

	# change to bytes (from KB)
	$dffree = $list[3] * 1024;
	$dref->{$name} = $dffree;

	return( 0 );
}

sub delete {

}

1;

