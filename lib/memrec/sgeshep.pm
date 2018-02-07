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
# RCSID $Id: sgeshep.pm 569 2013-01-15 22:00:00Z jbp $

package sgeshep;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

sub prep {
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($dp);

	opendir( $dp, '/proc' )
	  or print STDERR "** Error: cannot open file [/proc]\n";
	closedir($dp);

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $count, $l, $x, $dp, $fp );
	my @list = ();
	
	opendir( $dp, '/proc' );
	@list = grep { /^\d/ } readdir($dp);
	closedir($dp);

	$count = 0;
	foreach $l (@list) {
		open( $fp, "/proc/$l/cmdline" );
		$x = <$fp>;
		close($fp);
		if ( $x =~ m/sge_shepherd/ ) {
			$count++;
		}
	}

	$dref->{'jobs'} = $count;

	return( 0 );
}

sub delete {

}

1;
