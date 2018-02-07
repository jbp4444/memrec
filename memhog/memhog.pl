#!/usr/bin/perl

use Getopt::Std;
getopts('d:m:s:');

$size = 1000;
$spk  = 0;
$delay = 10;

if( defined($opt_d) ) {
	$delay = $opt_d + 0;
}
if( defined($opt_m) ) {
	$size = $opt_m + 0;
	if( $opt_m =~ m/k/ ) {
		$size *= 1000;
	} elsif( $opt_m =~ m/K/ ) {
		$size *= 1024;
	} elsif( $opt_m =~ m/m/ ) {
		$size *= 1000*1000;
	} elsif( $opt_m =~ m/M/ ) {
		$size *= 1024*1024;
	} elsif( $opt_m =~ m/g/ ) {
		$size *= 1000*1000*1000;
	} elsif( $opt_m =~ m/G/ ) {
		$size *= 1024*1024*1024;
	}
}
if( defined($opt_s) ) {
	$spk = $opt_s + 0;
	if( $opt_s =~ m/k/ ) {
		$spk *= 1000;
	} elsif( $opt_s =~ m/K/ ) {
		$spk *= 1024;
	} elsif( $opt_s =~ m/m/ ) {
		$spk *= 1000*1000;
	} elsif( $opt_s =~ m/M/ ) {
		$spk *= 1024*1024;
	} elsif( $opt_s =~ m/g/ ) {
		$spk *= 1000*1000*1000;
	} elsif( $opt_s =~ m/G/ ) {
		$spk *= 1024*1024*1024;
	}
}

$| = 1;
print "Starting with $size bytes\n";
print "  mem spike to $spk bytes\n";
print "  delays [$delay,$delay,$delay]\n";


$data1 = '1' x $size;
print "Got main memory\n";

sleep( $delay );

$data2 = '1' x $spk;
print "Got spike memory\n";

sleep( $delay );

$data2 = '';
print "Freed spike\n";

sleep( $delay );

$data1 = '';
print "Freed main memory\n";

print "Done!\n";

