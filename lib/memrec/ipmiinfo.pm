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
# RCSID $Id: ipmiinfo.pm 609 2013-04-23 19:59:13Z jbp $

package ipmiinfo;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $ipmitool_cmd = '/usr/bin/ipmitool';
my $ipmi_timeout = 15;                             # seconds
my $show_serial = 0;
my $show_partnum = 0;

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );

	if( lc($key) eq 'show_serial' ) {
		$show_serial = &convert_to_yesno( $val );
	} elsif( lc($key) eq 'show_partnum' ) {
		$show_partnum = &convert_to_yesno( $val );
	} elsif( lc($key) eq 'ipmitool' ) {
		$ipmitool_cmd = $val;
	} elsif( lc($key) eq 'ipmi_timeout' ) {
		$ipmi_timeout = $val + 0;
	}

	return;
}

sub new {
	my $class = shift;
	my $self = {};
	my ( $vendor, $model, $serial, $partnum, $x );
	
	$vendor = 'default-';
	$model = 'default';
	$serial = 'none';
	$partnum = 'none';
	
	# trick from Lincoln Stein's book "Network programming with Perl"
	eval {
		local $SIG{ALRM} = sub { die '__timeout__' };
		alarm($ipmi_timeout);
		open( $pp, "$ipmitool_cmd -I open fru list 2>&1 |" );
		while (<$pp>) {
			chomp( $_ );
			# Dell puts it in FRU Device 0/Board Mfg
			# 	: and Board Product
			if ( $_ =~ m/Board Mfg\s+\:\s+(.*)/ ) {
				$vendor = $1;
			}
			elsif ( $_ =~ m/Board Product\s+\:\s+(.*)/) {
				$model = $1;
			}
			elsif ( $_ =~ m/Board Serial\s+\:\s+(.*)/) {
				$serial = $1;
			}
			elsif ( $_ =~ m/Board Part Number\s+\:\s+(.*)/) {
				$partnum = $1;
			}
			elsif ( $_ eq '' ) {
				last;
			}
		}
		close($pp);
		alarm(0);
	};
	if ( $@ =~ m/__timeout__/ ) {
		# timeout could have happened AFTER we got the right data
		if( $vendor eq 'default' ) {
			$vendor = 'defaultx';	
		}
	}

	#$model =~ s/([A-Z])/\-$1/g;
	$model =~ s/PowerEdge/poweredge-/;

	$x = lc( $vendor . '-' . $model );
	$x =~ s/\s/\-/g;
	$x =~ s/\-+/\-/g;
	$x =~ s/\-+$//;
	$self->{'hostmodel'} = $x;
	$self->{'serialnum'} = lc( $serial );
	$self->{'partnum'} = lc( $partnum );
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	
	$dref->{'hostmodel'} = $self->{'hostmodel'};
	if( $show_serial ) {
		$dref->{'serialnum'} = $self->{'serialnum'};
	}
	if( $show_partnum ) {
		$dref->{'partnum'} = $self->{'partnum'};
	}

	return( 0 );	
}

sub delete {
	
}

1;
