#!/usr/bin/perl

use Getopt::Std;
getopts('vVhr:l:n:');

$remote_file = '/bdscratch/jbp1/memrec/iohog/largefile';
$local_file  = '/tmp/jbp1/largefile.x';
$num_copies  = 1;

if( defined($opt_r) ) {
	$remote_file = $opt_r;
}
if( defined($opt_l) ) {
	$local_file = $opt_l;
}
if( defined($opt_n) ) {
	$num_copies = $opt_n + 0;
}

# # # # # # # # # # # # # # # # # # # #
 # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # #

$local_dir = $local_file;
$local_dir =~ s/\/([^\/]+?)$//;
system( "mkdir -p $local_dir" ); 

($login,$pass,$uid,$gid) = getpwuid($<);
print "netid: $login\n";
print "executing: scp -B $login\@bdgpu-login-01:$remote_file.[0,1] $local_file\n";

for($i=0;$i<$num_copies;$i++) {
	$q = $i % 2;
	system( "scp -B $login\@bdgpu-login-01:$remote_file.$q $local_file" );
	unlink( $local_file );
}

