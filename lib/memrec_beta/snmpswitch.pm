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
# RCSID $Id: snmpswitch.pm 267 2011-09-04 11:16:47Z jbp $

package snmpswitch;
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

#use Net::SNMP;
use basesubs;
use wrapctr;

my $counter = 0;

# e.g.:  snmpwalk -On -c public 192.168.1.5 ifInOctets
my $OID_ifNumber        = '1.3.6.1.2.1.2.1.0';
my $OID_ifDescr         = '1.3.6.1.2.1.2.2.1.2';
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
my %oidmasterlist       = (
	$OID_ifInOctets      => 'in_octs',
	$OID_ifInUcastPkts   => 'in_Upkts',
	$OID_ifInNUcastPkts  => 'in_NUpkts',
	$OID_ifInDiscards    => 'in_dscds',
	$OID_ifInErrors      => 'in_errs',
	$OID_ifOutOctets     => 'out_octs',
	$OID_ifOutUcastPkts  => 'out_Upkts',
	$OID_ifOutNUcastPkts => 'out_NUpkts',
	$OID_ifOutDiscards   => 'out_dscds',
	$OID_ifOutErrors     => 'out_errs'
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
	my ( $oid, $nm, $k, $v, $p, $result );
	my $rawdata = {};

	while ( ( $oid, $nm ) = each %oidmasterlist ) {

		#print "getting oid [$oid]\n";
		$result = $session->get_bulk_request(
			-maxrepetitions => $nports,
			-varbindlist    => [$oid],
		);
		if ( !defined $result ) {
			printf "ERROR: %s.\n", $session->error();
		}

		while( ($k,$v) = each %$result ) {
			$k =~ m/(.*\.)(\d+)/;
			$p = $2 + 0;
			$rawdata->{"${nm}_$p"} = $v;
		}
	}

	return ($rawdata);
}

sub new {
	my $class    = shift;
	my $rem_ip   = shift(@_);
	my $rem_pswd = shift(@_);
	my $self     = {};
	my ( $i, $nports, $session, $err, $result, $rawdata, $portlist );

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
	$portlist = {};
	$result = $session->get_request( -varbindlist => [$OID_ifNumber], );
	if ( !defined $result ) {
		print
"** Warning:  cannot get ifNumber from $rem_ip, assuming 24-port switch\n";
		$nports = 24;
	}
	else {
		$nports = $result->{$OID_ifNumber} + 0;
		#print "** Notice:  $rem_ip is a $nports -port switch\n";
	}
	
	$result = $session->get_bulk_request(
			-maxrepetitions => $nports,
			-varbindlist    => [$OID_ifDescr],
	);	
	if ( !defined $result ) {
		print
"** Warning:  cannot get ifNumber from $rem_ip, assuming 24-port switch\n";
		$nports = 24;
		for($i=0;$i<$nports;$i++) {
			$portlist->{$i} = 'default';
		}
	}
	else {
		while( ($k,$v) = each %$result ) {
			$k =~ m/(.*\.)(\d+)/;
			$p = $2 + 0;
			$portlist->{$p} = $v;
			#print "port [$k] [$p] [$v]\n";
		}
	}

	$rawdata = &get_snmp_data( $session, $nports );
	$self->{'rawdata'}    = $rawdata;
	$self->{'portlist'}   = $portlist;
	$self->{'session'}    = $session;
	$self->{'switch_ip'}  = $rem_ip;
	$self->{'num_ports'}  = $nports;
	$self->{'switch_ctr'} = $counter;
	$counter++;
	$self->{'last_tstamp'} = 0;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $c, $nports, $i, $session );
	my %delta_bytes_in       = ();
	my %delta_bytes_out      = ();
	my %delta_packets_in     = ();
	my %delta_packets_out    = ();
	my %delta_packeterrs_in  = ();
	my %delta_packeterrs_out = ();
	my $tstamp               = $dref->{'tstamp'};
	my $last_tstamp          = $self->{'last_tstamp'};
	my ($portlist,$olddata,$rawdata);

	$c        = $self->{'switch_ctr'};
	$nports   = $self->{'num_ports'};
	$session  = $self->{'session'};
	$olddata  = $self->{'rawdata'};
	$portlist = $self->{'portlist'};

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$last_tstamp = $tstamp - 1;
	}
	
	$rawdata = &get_snmp_data( $session, $nports );

	foreach $i ( keys(%$portlist) ) {
		$delta_bytes_in{$i} =
		  &delta( $rawdata->{"in_octs_$i"}, $olddata->{"in_octs_$i"} );
		$delta_packets_in{$i} =
		  &delta( $rawdata->{"in_Upkts_$i"},  $olddata->{"in_Upkts_$i"} ) +
		  &delta( $rawdata->{"in_NUpkts_$i"}, $olddata->{"in_NUpkts_$i"} );
		$delta_packeterrs_in{$i} =
		  &delta( $rawdata->{"in_errs_$i"},  $olddata->{"in_errs_$i"} ) +
		  &delta( $rawdata->{"in_dscds_$i"}, $olddata->{"in_dscds_$i"} );
		$delta_bytes_out{$i} =
		  &delta( $rawdata->{"out_octs_$i"}, $olddata->{"out_octs_$i"} );
		$delta_packets_out{$i} =
		  &delta( $rawdata->{"out_Upkts_$i"},  $olddata->{"out_Upkts_$i"} ) +
		  &delta( $rawdata->{"out_NUpkts_$i"}, $olddata->{"out_NUpkts_$i"} );
		$delta_packeterrs_out{$i} =
		  &delta( $rawdata->{"out_errs_$i"},  $olddata->{"out_errs_$i"} ) +
		  &delta( $rawdata->{"out_dscds_$i"}, $olddata->{"out_dscds_$i"} );
	}

	foreach $i ( keys(%$portlist) ) {
		$dref->{"in_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_in{$i} / ( $tstamp - $last_tstamp ) );
		$dref->{"out_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_out{$i} / ( $tstamp - $last_tstamp ) );
		$dref->{"in_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_in{$i} / ( $tstamp - $last_tstamp ) );
		$dref->{"out_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_out{$i} / ( $tstamp - $last_tstamp ) );
		$dref->{"in_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_in{$i} / ( $tstamp - $last_tstamp ) );
		$dref->{"out_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_out{$i} / ( $tstamp - $last_tstamp ) );
	}

	$self->{'rawdata'} = $rawdata;
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
