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
# RCSID $Id: snmpswitch.pm 179 2011-06-09 20:46:21Z jbp $

package snmpswitch2;
use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new );

use basesubs;
use wrapctr;

my $snmpcmd = '/usr/bin/snmpwalk';
my $counter = 0;

# e.g.:  snmpwalk -On -c public 192.168.1.5 ifInOctets
my $OID_ifNumber = '1.3.6.1.2.1.2.1.0';

# ifHCInOctets(1.3.6.1.2.1.31.1.1.1.6)
# ifHCInUcastPkts(.1.3.6.1.2.1.31.1.1.1.7)
# ifHCInMulticastPkts(1.3.6.1.2.1.31.1.1.1.8)
# ifHCInBroadcastPkts(1.3.6.1.2.1.31.1.1.1.9)
# ifHCOutOctets(1.3.6.1.2.1.31.1.1.1.10)
# ifHCOutUcastPkts(1.3.6.1.2.1.31.1.1.1.11)
# ifHCOutMulticastPkts(1.3.6.1.2.1.31.1.1.1.12)
# ifHCOutBroadcastPkts(1.3.6.1.2.1.31.1.1.1.13)

sub get_snmp_data {
	my $rem_ip   = shift(@_);
	my $rem_pswd = shift(@_);
	my $nports   = shift(@_);
	my ( $i, $k, $v, $pp );
	my @fld        = ();
	my %in_octs    = ();
	my %in_Upkts   = ();
	my %in_NUpkts  = ();
	my %in_errs    = ();
	my %in_dscds   = ();
	my %out_octs   = ();
	my %out_Upkts  = ();
	my %out_NUpkts = ();
	my %out_errs   = ();
	my %out_dscds  = ();

# this is a trade-off between one snmpwalk call with one start-up penalty but more data
# vs. multiple snmpwalk commands for each targeted data-item
	open( $pp, "$snmpcmd -On -c $rem_pswd $rem_ip ifEntry |" );
	while (<$pp>) {
		chomp($_);
		@fld = split( ' ', $_ );
		$k   = $fld[0];
		$v   = $fld[3] + 0;
		if ( $k =~ m/$OID_ifInOctets.(\d+)/ ) {
			$in_octs{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifInUcastPkts.(\d+)/ ) {
			$in_Upkts{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifInNUcastPkts.(\d+)/ ) {
			$in_NUpkts{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifInDiscards.(\d+)/ ) {
			$in_dscds{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifInErrors.(\d+)/ ) {
			$in_errs{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifOutOctets.(\d+)/ ) {
			$out_octs{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifOutUcastPkts.(\d+)/ ) {
			$out_Upkts{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifOutNUcastPkts.(\d+)/ ) {
			$out_NUpkts{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifOutDiscards.(\d+)/ ) {
			$out_dscds{ $1 + 0 } = $v;
		}
		elsif ( $k =~ m/$OID_ifOutErrors.(\d+)/ ) {
			$out_errs{ $1 + 0 } = $v;
		}
		else {
			print "[$k] [$v]\n";
		}
	}
	close($pp);

	return (
		\%in_octs,  \%in_Upkts,  \%in_NUpkts,  \%in_errs,  \%in_dscds,
		\%out_octs, \%out_Upkts, \%out_NUpkts, \%out_errs, \%out_dscds
	);
}

sub new {
	my $class    = shift;
	my $rem_ip   = shift(@_);
	my $rem_pswd = shift(@_);
	my $self     = {};
	my ( $i,        $nports,    $pp );
	my ( $in_octs,  $in_Upkts,  $in_NUpkts, $in_errs, $in_dscds );
	my ( $out_octs, $out_Upkts, $out_NUpkts, $out_errs, $out_dscds );

	if ( $rem_pswd =~ m// ) {
		$rem_pswd = 'public';
	}

	# get snmp data here (via SNMP)
	# so that we know how many ports?
	$nports = 0;
	open( $pp, "$snmpcmd -On -c $rem_pswd $rem_ip ifNumber.0 |" );
	$i = <$pp>;
	$i =~ s/.*INTEGER\://;
	$nports = $i + 0;
	close($pp);

	print "** Notice:  $rem_ip is a $nports -port switch\n";

	(
		$in_octs,  $in_Upkts,  $in_NUpkts,  $in_errs,  $in_dscds,
		$out_octs, $out_Upkts, $out_NUpkts, $out_errs, $out_dscds
	  )
	  = &get_snmp_data( $rem_ip, $rem_pswd, $nports );

	for ( $i = 0 ; $i < $nports ; $i++ ) {
		$self->{"in_octs_$i"}    = wrapctr->new( $in_octs->{$i} );
		$self->{"in_Upkts_$i"}   = wrapctr->new( $in_Upkts->{$i} );
		$self->{"in_NUpkts_$i"}  = wrapctr->new( $in_NUpkts->{$i} );
		$self->{"in_errs_$i"}    = wrapctr->new( $in_errs->{$i} );
		$self->{"in_dscds_$i"}   = wrapctr->new( $in_dscds->{$i} );
		$self->{"out_octs_$i"}   = wrapctr->new( $out_octs->{$i} );
		$self->{"out_Upkts_$i"}  = wrapctr->new( $out_Upkts->{$i} );
		$self->{"out_NUpkts_$i"} = wrapctr->new( $out_NUpkts->{$i} );
		$self->{"out_errs_$i"}   = wrapctr->new( $out_errs->{$i} );
		$self->{"out_dscds_$i"}  = wrapctr->new( $out_dscds->{$i} );
	}
	$self->{'switch_ip'}   = $rem_ip;
	$self->{'switch_pswd'} = $rem_pswd;
	$self->{'num_ports'}   = $nports;
	$self->{'switch_ctr'}  = $counter;
	$counter++;
	$self->{'last_tstamp'} = 0;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $c, $rem_ip, $rem_pswd, $nports, $i );
	my @delta_bytes_in       = ();
	my @delta_bytes_out      = ();
	my @delta_packets_in     = ();
	my @delta_packets_out    = ();
	my @delta_packeterrs_in  = ();
	my @delta_packeterrs_out = ();
	my $tstamp               = $dref->{'tstamp'};
	my $last_tstamp          = $self->{'last_tstamp'};
	my ( $in_octs,  $in_Upkts,  $in_NUpkts,  $in_errs,  $in_dscds );
	my ( $out_octs, $out_Upkts, $out_NUpkts, $out_errs, $out_dscds );

	$c        = $self->{'switch_ctr'};
	$rem_ip   = $self->{'switch_ip'};
	$rem_pswd = $self->{'switch_pswd'};
	$nports   = $self->{'num_ports'};

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$last_tstamp = $tstamp - 1;
	}

	(
		$in_octs,  $in_Upkts,  $in_NUpkts,  $in_errs,  $in_dscds,
		$out_octs, $out_Upkts, $out_NUpkts, $out_errs, $out_dscds
	  )
	  = &get_snmp_data( $rem_ip, $rem_pswd, $nports );

	foreach $i ( keys(%$in_octs) ) {
		@fld = split( /\s+/, $x );
		$delta_bytes_in[$i]   = $self->{"in_octs_$i"}->update( $in_octs->{$i} );
		$delta_packets_in[$i] =
		  $self->{"in_Upkts_$i"}->update( $in_Upkts->{$i} ) +
		  $self->{"in_NUpkts_$i"}->update( $in_NUpkts->{$i} );
		$delta_packeterrs_in[$i] =
		  $self->{"in_errs_$i"}->update( $in_errs->{$i} ) +
		  $self->{"in_dscds_$i"}->update( $in_dscds->{$i} );
		$delta_bytes_out[$i] =
		  $self->{"out_octs_$i"}->update( $out_octs->{$i} );
		$delta_packets_out[$i] =
		  $self->{"out_Upkts_$i"}->update( $out_Upkts->{$i} ) +
		  $self->{"out_NUpkts_$i"}->update( $out_NUpkts->{$i} );
		$delta_packeterrs_out[$i] =
		  $self->{"out_errs_$i"}->update( $out_errs->{$i} ) +
		  $self->{"out_dscds_$i"}->update( $out_dscds->{$i} );
	}

	foreach $i ( keys(%$in_octs) ) {
		$dref->{"in_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_in[$i] / ( $tstamp - $last_tstamp ) );
		$dref->{"out_octs_s${c}_p$i"} =
		  &round00( $delta_bytes_out[$i] / ( $tstamp - $last_tstamp ) );
		$dref->{"in_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_in[$i] / ( $tstamp - $last_tstamp ) );
		$dref->{"out_pkts_s${c}_p$i"} =
		  &round00( $delta_packets_out[$i] / ( $tstamp - $last_tstamp ) );
		$dref->{"in_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_in[$i] / ( $tstamp - $last_tstamp ) );
		$dref->{"out_errs_s${c}_p$i"} =
		  &round00( $delta_packeterrs_out[$i] / ( $tstamp - $last_tstamp ) );
	}

	$self->{'last_tstamp'} = $tstamp;
	
	$dref->{"switch_ip_s$c"} = $rem_ip;
	$dref->{"num_ports_s$c"} = $nports;

	return (0);
}

sub delete {
}

1;
