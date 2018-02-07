#!/usr/bin/perl

use strict;
use warnings;

use Net::SNMP;

my $OID_sysUpTime   = '1.3.6.1.2.1.1.3.0';
my $OID_sysLocation = '1.3.6.1.2.1.1.6.0';

my ($session, $error) = Net::SNMP->session(
   -hostname  => shift || 'localhost',
   -community => shift || 'public',
);

if (!defined $session) {
   printf "ERROR: %s.\n", $error;
   exit 1;
}

my $result = $session->get_request(-varbindlist => [ $OID_sysUpTime ],);
if (!defined $result) {
   printf "ERROR: %s.\n", $session->error();
   $session->close();
   exit 1;
}
printf "The sysUpTime for host '%s' is %s.\n",
       $session->hostname(), $result->{$OID_sysUpTime};

my $result = $session->get_request(-varbindlist => [ $OID_sysLocation ],);
if (!defined $result) {
   printf "ERROR: %s.\n", $session->error();
   $session->close();
   exit 1;
}
printf "The sysLocation for host '%s' is %s.\n",
       $session->hostname(), $result->{$OID_sysLocation};

$session->close();

exit 0;

