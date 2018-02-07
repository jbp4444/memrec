#!/usr/bin/perl
#
# (C) 2010-2011, John Pormann, Duke University
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
# RCSID $Id: snmpswitch.pm 185 2011-06-14 17:17:15Z jbp $

package snmpswitch4;
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

#use Net::SNMP;
use basesubs;

my $counter = 0;

# e.g.:  snmpwalk -On -c public 192.168.1.5 ifInOctets
my $OID_ifNumber        = '1.3.6.1.2.1.2.1.0';
my $OID_ifInOctets      = '1.3.6.1.2.1.2.2.1.10';
my $OID_ifInUcastPkts   = '1.3.6.1.2.1.2.2.1.11';
my $OID_ifInNUcastPkts  = '1.3.6.1.2.1.2.2.1.12';
my $OID_ifInDiscards    = '1.3.6.1.2.1.2.2.1.13';
my $OID_ifInErrors      = '1.3.6.1.2.1.2.2.1.14';
my $OID_ifOutOctets     = '1.3.6.1.2.1.2.2.1.16';
my $OID_ifOutUcastPkts  = '1.3.6.1.2.1.2.2.1.17';
my $OID_ifOutNUcastPkts = '1.3.6.1.2.1.2.2.1.18';
my $OID_ifOutDiscards   = '1.3.6.1.2.1.2.2.1.19';
my $OID_ifOutErrors     = '1.3.6.1.2.1.2.2.1.20';
my @oidmasterlist       = (
	$OID_ifInOctets,     $OID_ifInUcastPkts,   $OID_ifInNUcastPkts,
	$OID_ifInDiscards,   $OID_ifInErrors,      $OID_ifOutOctets,
	$OID_ifOutUcastPkts, $OID_ifOutNUcastPkts, $OID_ifOutDiscards,
	$OID_ifOutErrors
);

# ifHCInOctets(1.3.6.1.2.1.31.1.1.1.6)
# ifHCInUcastPkts(.1.3.6.1.2.1.31.1.1.1.7)
# ifHCInMulticastPkts(1.3.6.1.2.1.31.1.1.1.8)
# ifHCInBroadcastPkts(1.3.6.1.2.1.31.1.1.1.9)
# ifHCOutOctets(1.3.6.1.2.1.31.1.1.1.10)
# ifHCOutUcastPkts(1.3.6.1.2.1.31.1.1.1.11)
# ifHCOutMulticastPkts(1.3.6.1.2.1.31.1.1.1.12)
# ifHCOutBroadcastPkts(1.3.6.1.2.1.31.1.1.1.13)

sub get_snmp_data {
	my $session = shift(@_);
	my $nports  = shift(@_);
	my ( $oid, $k, $v, $n );
	my $rawdata = {};

	foreach $oid (@oidmasterlist) {

		#print "getting oid [$oid]\n";
		$result = $session->get_bulk_request(
			-maxrepetitions => $nports,
			-varbindlist    => [$oid],
		);
		if ( !defined $result ) {
			printf "ERROR: %s.\n", $session->error();
		}

		while( ($k,$v) = each %$result ) {
			if ( $k =~ m/$OID_ifInOctets.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"in_octs_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifInUcastPkts.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"in_Upkts_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifInNUcastPkts.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"in_NUpkts_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifInDiscards.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"in_dscds_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifInErrors.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"in_errs_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifOutOctets.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"out_octs_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifOutUcastPkts.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"out_Upkts_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifOutNUcastPkts.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"out_NUpkts_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifOutDiscards.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"out_dscds_$n"} = $v;
			}
			elsif ( $k =~ m/$OID_ifOutErrors.(\d+)/ ) {
				$n = $1 + 0;
				$rawdata->{"out_errs_$n"} = $v;
			}
			else {
				print "[$k] [$v]\n";
			}
		}
	}

	return ($rawdata);
}

sub new {
	my $class    = shift;
	my $rem_ip   = shift(@_);
	my $rem_pswd = shift(@_);
	my $self     = {};
	my ( $i, $nports, $session, $err, $result, $rawdata );

	if ( $rem_pswd =~ m// ) {
		$rem_pswd = 'public';
	}

	# get snmp data here (via SNMP)
	# so that we know how many ports?
	( $session, $err ) = Net::SNMP->session(
		-hostname  => $rem_ip,
		-community => $rem_pswd,
		-version   => 'snmpv2c',
	);
	if ( !defined($session) ) {
		print "** ERROR: cannot open connection to [$rem_ip]\n";
		return;
	}

	#$session->max_msg_size(5000);

	$nports = 0;
	$result = $session->get_request( -varbindlist => [$OID_ifNumber], );
	if ( !defined $result ) {
		print
"** Warning:  cannot get ifNumber from $rem_ip, assuming 24-port switch\n";
		$nports = 24;
	}
	else {
		$nports = $result->{$OID_ifNumber} + 0;
		print "** Notice:  $rem_ip is a $nports -port switch\n";
	}

	$rawdata = &get_snmp_data( $session, $nports );
	$self->{'c1'} = $rawdata;
	$self->{'c2'} = $rawdata;
	$self->{'c3'} = $rawdata;
	$self->{'c4'} = $rawdata;

	$self->{'session'}    = $session;
	$self->{'switch_ip'}  = $rem_ip;
	$self->{'num_ports'}  = $nports;
	$self->{'switch_ctr'} = $counter;
	$self->{'qmod'}       = 4;
	$self->{'qctr'}       = 1;
	$counter++;
	$self->{'last_tstamp'} = 0;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $c, $nports, $i, $session );
	my @delta_bytes_in           = ();
	my @delta_bytes_out          = ();
	my @delta_packets_in         = ();
	my @delta_packets_out        = ();
	my @delta_packeterrs_in      = ();
	my @delta_packeterrs_out     = ();
	my @max_delta_bytes_in       = ();
	my @max_delta_bytes_out      = ();
	my @max_delta_packets_in     = ();
	my @max_delta_packets_out    = ();
	my @max_delta_packeterrs_in  = ();
	my @max_delta_packeterrs_out = ();
	my $tstamp                   = $dref->{'tstamp'};
	my $last_tstamp              = $self->{'last_tstamp'};
	my ( $rawdata0, $rawdata1, $rawdata2, $rawdata3, $rawdata4 );
	my ( $qmod,     $qctr );

	$c       = $self->{'switch_ctr'};
	$nports  = $self->{'num_ports'};
	$session = $self->{'session'};
	$qmod = $self->{'qmod'};
	$qctr = $self->{'qctr'};

	# get the old data
	$rawdata4 = $self->{'c4'};
	$rawdata3 = $self->{'c3'};
	$rawdata2 = $self->{'c2'};
	$rawdata1 = $self->{'c1'};

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$last_tstamp = $tstamp - 1;
	}

	# get new data
	$rawdata0 = &get_snmp_data( $session, $nports );

	print "data [$rawdata0] [$rawdata1] [$rawdata2] [$rawdata3] [$rawdata4]\n";

	# per-port data (low-res)
	for ( $i = 0 ; $i < $nports ; $i++ ) {
		$delta_bytes_in[$i] =
		  &delta( $rawdata0->{"in_octs_$i"}, $rawdata4->{"in_octs_$i"} );
		$delta_packets_in[$i] =
		  &delta( $rawdata0->{"in_Upkts_$i"},  $rawdata4->{"in_Upkts_$i"} ) +
		  &delta( $rawdata0->{"in_NUpkts_$i"}, $rawdata4->{"in_NUpkts_$i"} );
		$delta_packeterrs_in[$i] =
		  &delta( $rawdata0->{"in_errs_$i"},  $rawdata4->{"in_errs_$i"} ) +
		  &delta( $rawdata0->{"in_dscds_$i"}, $rawdata4->{"in_dscds_$i"} );
		$delta_bytes_out[$i] =
		  &delta( $rawdata0->{"out_octs_$i"}, $rawdata4->{"out_octs_$i"} );
		$delta_packets_out[$i] =
		  &delta( $rawdata0->{"out_Upkts_$i"},  $rawdata4->{"out_Upkts_$i"} ) +
		  &delta( $rawdata0->{"out_NUpkts_$i"}, $rawdata4->{"out_NUpkts_$i"} );
		$delta_packeterrs_out[$i] =
		  &delta( $rawdata0->{"out_errs_$i"},  $rawdata4->{"out_errs_$i"} ) +
		  &delta( $rawdata0->{"out_dscds_$i"}, $rawdata4->{"out_dscds_$i"} );
	}

	for ( $i = 0 ; $i < $nports ; $i++ ) {
		$dref->{"in_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_in[$i] / ($qmod*($tstamp - $last_tstamp )) );
		$dref->{"out_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_out[$i] / ($qmod*($tstamp - $last_tstamp )) );
		$dref->{"in_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_in[$i] / ($qmod*($tstamp - $last_tstamp )) );
		$dref->{"out_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_out[$i] / ($qmod*($tstamp - $last_tstamp )) );
		$dref->{"in_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_in[$i] / ($qmod*($tstamp - $last_tstamp )) );
		$dref->{"out_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_out[$i] / ($qmod*($tstamp - $last_tstamp )) );
	}

	if ( $qctr == $qmod ) {

		# compute the max of the high-res data
		print "computing max of high-res data\n";

		for ( $i = 0 ; $i < $nports ; $i++ ) {
			$max_delta_bytes_in[$i] = &max4(
				&delta( $rawdata0->{"in_octs_$i"}, $rawdata1->{"in_octs_$i"} ),
				&delta( $rawdata1->{"in_octs_$i"}, $rawdata2->{"in_octs_$i"} ),
				&delta( $rawdata2->{"in_octs_$i"}, $rawdata3->{"in_octs_$i"} ),
				&delta( $rawdata3->{"in_octs_$i"}, $rawdata4->{"in_octs_$i"} )
			);
			$max_delta_packets_in[$i] = &max4(
				&delta(
					$rawdata0->{"in_Upkts_$i"}, $rawdata1->{"in_Upkts_$i"}
				  ) + &delta(
					$rawdata0->{"in_NUpkts_$i"},
					$rawdata1->{"in_NUpkts_$i"}
				  ),
				&delta(
					$rawdata1->{"in_Upkts_$i"}, $rawdata2->{"in_Upkts_$i"}
				  ) + &delta(
					$rawdata1->{"in_NUpkts_$i"},
					$rawdata2->{"in_NUpkts_$i"}
				  ),
				&delta(
					$rawdata2->{"in_Upkts_$i"}, $rawdata3->{"in_Upkts_$i"}
				  ) + &delta(
					$rawdata2->{"in_NUpkts_$i"},
					$rawdata3->{"in_NUpkts_$i"}
				  ),
				&delta(
					$rawdata3->{"in_Upkts_$i"}, $rawdata4->{"in_Upkts_$i"}
				  ) + &delta(
					$rawdata3->{"in_NUpkts_$i"},
					$rawdata4->{"in_NUpkts_$i"}
				  )
			);
			$max_delta_packeterrs_in[$i] = &max4(
				&delta( $rawdata0->{"in_errs_$i"}, $rawdata1->{"in_errs_$i"} ) +
				  &delta(
					$rawdata0->{"in_dscds_$i"},
					$rawdata1->{"in_dscds_$i"}
				  ),
				&delta( $rawdata1->{"in_errs_$i"}, $rawdata2->{"in_errs_$i"} ) +
				  &delta(
					$rawdata1->{"in_dscds_$i"},
					$rawdata2->{"in_dscds_$i"}
				  ),
				&delta( $rawdata2->{"in_errs_$i"}, $rawdata3->{"in_errs_$i"} ) +
				  &delta(
					$rawdata2->{"in_dscds_$i"},
					$rawdata3->{"in_dscds_$i"}
				  ),
				&delta( $rawdata3->{"in_errs_$i"}, $rawdata4->{"in_errs_$i"} ) +
				  &delta(
					$rawdata3->{"in_dscds_$i"},
					$rawdata4->{"in_dscds_$i"}
				  )
			);
			$max_delta_bytes_out[$i] = &max4(
				&delta(
					$rawdata0->{"out_octs_$i"}, $rawdata1->{"out_octs_$i"}
				),
				&delta(
					$rawdata1->{"out_octs_$i"}, $rawdata2->{"out_octs_$i"}
				),
				&delta(
					$rawdata2->{"out_octs_$i"}, $rawdata3->{"out_octs_$i"}
				),
				&delta(
					$rawdata3->{"out_octs_$i"}, $rawdata4->{"out_octs_$i"}
				)
			);
			$max_delta_packets_out[$i] = &max4(
				&delta( $rawdata0->{"out_Upkts_$i"},
					$rawdata1->{"out_Upkts_$i"} ) + &delta(
					$rawdata0->{"out_NUpkts_$i"},
					$rawdata1->{"out_NUpkts_$i"}
					),
				&delta( $rawdata1->{"out_Upkts_$i"},
					$rawdata2->{"out_Upkts_$i"} ) + &delta(
					$rawdata1->{"out_NUpkts_$i"},
					$rawdata2->{"out_NUpkts_$i"}
					),
				&delta( $rawdata2->{"out_Upkts_$i"},
					$rawdata3->{"out_Upkts_$i"} ) + &delta(
					$rawdata2->{"out_NUpkts_$i"},
					$rawdata3->{"out_NUpkts_$i"}
					),
				&delta( $rawdata3->{"out_Upkts_$i"},
					$rawdata4->{"out_Upkts_$i"} ) + &delta(
					$rawdata3->{"out_NUpkts_$i"},
					$rawdata4->{"out_NUpkts_$i"}
					)
			);
			$max_delta_packeterrs_out[$i] = &max4(
				&delta(
					$rawdata0->{"out_errs_$i"}, $rawdata1->{"out_errs_$i"}
				  ) + &delta(
					$rawdata0->{"out_dscds_$i"},
					$rawdata1->{"out_dscds_$i"}
				  ),
				&delta(
					$rawdata1->{"out_errs_$i"}, $rawdata2->{"out_errs_$i"}
				  ) + &delta(
					$rawdata1->{"out_dscds_$i"},
					$rawdata2->{"out_dscds_$i"}
				  ),
				&delta(
					$rawdata2->{"out_errs_$i"}, $rawdata3->{"out_errs_$i"}
				  ) + &delta(
					$rawdata2->{"out_dscds_$i"},
					$rawdata3->{"out_dscds_$i"}
				  ),
				&delta(
					$rawdata3->{"out_errs_$i"}, $rawdata4->{"out_errs_$i"}
				  ) + &delta(
					$rawdata3->{"out_dscds_$i"},
					$rawdata4->{"out_dscds_$i"}
				  )
			);
		}

		for ( $i = 0 ; $i < $nports ; $i++ ) {
			$dref->{"max_in_octs_s${c}_p$i"} =
			  &round00( $max_delta_bytes_in[$i] / ( $tstamp - $last_tstamp ) );
			$dref->{"max_out_octs_s${c}_p$i"} =
			  &round00( $max_delta_bytes_out[$i] / ( $tstamp - $last_tstamp ) );
			$dref->{"max_in_pkts_s${c}_p$i"} =
			  &round00(
				$max_delta_packets_in[$i] / ( $tstamp - $last_tstamp ) );
			$dref->{"max_out_pkts_s${c}_p$i"} =
			  &round00(
				$max_delta_packets_out[$i] / ( $tstamp - $last_tstamp ) );
			$dref->{"max_in_errs_s${c}_p$i"} =
			  &round00(
				$max_delta_packeterrs_in[$i] / ( $tstamp - $last_tstamp ) );
			$dref->{"max_out_errs_s${c}_p$i"} =
			  &round00(
				$max_delta_packeterrs_out[$i] / ( $tstamp - $last_tstamp ) );
		}

		$self->{'qctr'} = 1;
	}
	else {
		$self->{'qctr'} = $qctr + 1;
	}

	# bump all the arrays of counters by one time-step
	$self->{'c1'} = $rawdata0;
	$self->{'c2'} = $rawdata1;
	$self->{'c3'} = $rawdata2;
	$self->{'c4'} = $rawdata3;
	$self->{'last_tstamp'} = $tstamp;

	$dref->{"switch_ip_s$c"} = $self->{'switch_ip'};
	$dref->{"num_ports_s$c"} = $nports;

	return (0);
}

sub delete {
	my $self = shift;
	my ($session);

	$session = $self->{'session'};
	$session->close();
}

1;
