#!/usr/bin/perl

mkdir( "tmp.$$" );
chdir( "tmp.$$" );

for($i=0;$i<4;$i++) {
	if( ! -e "foo.$i" ) {
		mkdir( "foo.$i" );
	}
}

opendir( DP, '.' );
@files = readdir( DP );
closedir( DP );

