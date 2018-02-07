#!/usr/bin/perl

use strict;
use warnings;

use Net::SNMP;

my $OID_base = '1.3.6.1.2.1.2.2.1.10';  # base.1 base.2 etc.

my ($session, $error) = Net::SNMP->session(
   -hostname  => shift || 'localhost',
   -community => shift || 'public',
   -version => 'snmpv2c',
);
if (!defined $session) {
   printf "ERROR: %s.\n", $error;
   exit 1;
}

my @oidlist = ();
my ($i);
for($i=1;$i<=24;$i++) {
	push( @oidlist, "$OID_base.$i" );	
}

my $result = $session->get_request(
	-varbindlist => \@oidlist,
);
if (!defined $result) {
   printf "ERROR: %s.\n", $session->error();
   $session->close();
   exit 1;
}

my ($k,$v);
foreach $k ( keys(%$result) ) {
	$v = $result->{$k};
	print "[$k] [$v]\n";
}

$session->close();

exit 0;

