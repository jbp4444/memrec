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
# RCSID $Id: etcduke.pm 425 2012-08-15 14:13:45Z jbp $

package etcduke;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

sub prep {
}

sub new {
	my $class     = shift;
	my $hostmodel = 'generic-host';
	my ( $vendor, $model, $k, $flag, $fp );
	my $vendor_file = '/etc/duke/vendor';
	my $model_file  = '/etc/duke/model';
	my $self        = {};

	$flag = 0;
	open( $fp, $vendor_file ) or $flag = 1;
	if ($flag) {
		print STDERR "** Error: cannot open file [$vendor_file]\n";
		$vendor = 'unknown';
	}
	else {
		$_ = <$fp>;
		chomp($_);
		$vendor = lc($_);
		close($fp);

		# we only need the vendors first name (Dell, Sun, IBM, etc.)
		$vendor =~ s/(.*?)\s+(.*)/$1/;
		$vendor =~ s/,//g;
	}
	$flag = 0;
	open( $fp, $model_file ) or $flag = 1;
	if ($flag) {
		print STDERR "** Error: cannot open file [$model_file]\n";
		$model = 'unknown';
	}
	else {
		$_ = <$fp>;
		chomp($_);
		$model = lc($_);
		close($fp);

		# we can ignore some of the model name too
		$model =~ s/sun fire//;
		$model =~ s/poweredge//;
		$model =~ s/virtual platform//;
		$model =~ s/\s+//g;
	}
	$hostmodel = $vendor . ' ' . $model;
	$hostmodel =~ s/\s*$//;
	$hostmodel =~ s/\s+/ /g;
	$hostmodel =~ s/ /-/g;
	$self->{'hostmodel'} = $hostmodel;
	bless( $self, $class );
	return ($self);
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);

	$dref->{'hostmodel'} = $self->{'hostmodel'};

	return( 0 );
}

sub delete {

}

1;

