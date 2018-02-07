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
# RCSID $Id: power.pm 622 2013-05-10 14:24:47Z jbp $

package power;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

# too difficult to keep up with delloem specific ipmitool
# : never really used kwh measurement anyway
my $ipmitool_cmd = '/usr/bin/ipmitool';
my $ipmi_timeout = 15;                             # seconds
my $wattsup_cmd  = '/admin/reports/bin/wattsup';
my $force_ipmi = 0;
my $force_usb = 0;

sub prep {
	# modify local vars
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );

	if( lc($key) eq 'ipmitool' ) {
		$ipmitool_cmd = $val;
	} elsif( lc($key) eq 'ipmi_timeout' ) {
		$ipmi_timeout = $val + 0;
	} elsif( lc($key) eq 'force_ipmi' ) {
		$force_ipmi = &convert_to_yesno( $val );
	} elsif( lc($key) eq 'force_usb' ) {
		$force_usb = &convert_to_yesno( $val );
	}

	return;
}

sub new {
	my $class = shift;
	my $self  = {};
	my ( $cmd1, $wu_flag );

	$wu_flag = 0;
	if ( -e '/dev/ttyUSB0' ) {
		# assume any ttyUSB0 must be a WattsUp meter
		$cmd1    = "$wattsup_cmd -c 1 ttyUSB0 watts 2>&1 |";
		$wu_flag = 1;
	}
	else {
		$cmd1     = "$ipmitool_cmd -I open sdr list 2>&1 |";
	}

	if( $force_ipmi ) {
		$cmd1     = "$ipmitool_cmd -I open sdr list 2>&1 |";
	}
	if( $force_usb ) {
		$cmd1    = "$wattsup_cmd -c 1 ttyUSB0 watts 2>&1 |";
		$wu_flag = 1;
	}

	$self->{'cmd1'}    = $cmd1;
	$self->{'wu_flag'} = $wu_flag;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $watts, $flag, $pp );
	my $cmd1    = $self->{'cmd1'};
	my $wu_flag = $self->{'wu_flag'};

	$watts = -1.0;
	if ( $cmd1 ne '' ) {

		# trick from Lincoln Stein's book "Network programming with Perl"
		eval {
			local $SIG{ALRM} = sub { die '__timeout__' };
			alarm($ipmi_timeout);
			open( $pp, $cmd1 );
			while (<$pp>) {
				# Dell calls it "System Level"
				if ( $_ =~ m/System Level\s+\|\s+(.*)/ ) {
					$watts = $1 + 0;
					last;
				}
				# Dell M620 calls it 'Pwr Consumption'
				elsif ( $_ =~ m/Pwr Consumption\s+\|\s+(.*)/) {
					$watts = $1 + 0;
					last;
				}
				# IBM calls it 'AvgPwrIns1'
				# : hmm, it's not a per-blade power number
				#elsif ( $_ =~ m/AvgPwrIns1\s+\|\s+(.*)/) {
				#	$watts = $1 + 0;
				#}				
				# Intel loaner calls it "PS1 Input Power"
				# : sometimes PS2 input power is non-zero (but sometimes it is zero?)
				elsif ( $_ =~ m/PS\d Input Power\s+\|\s+(.*)/) {
					if( $watts < 0 ) {
				    	$watts = $1 + 0;
					} else {
						$watts += ($1 + 0);
					}
					last;
			    }
				elsif ( $wu_flag and ( $_ =~ m/^(\d.*)/ ) ) {

					# wattsup meter just prints numbers
					$watts = $1 + 0;
					last;
				}
				elsif ( $_ =~ m/^Error/ ) {
					$watts = -1.2;
					last;
				}
			}
			close($pp);
			alarm(0);
		};
		if ( $@ =~ m/__timeout__/ ) {
			# timeout could have happened AFTER we got the right data
			if( $watts < 0 ) {
				$watts = -1.3;			
			}
		}
	}

	$dref->{'watts'} = $watts;

	return( 0 );
}

sub delete {

}

1;
