#!/usr/bin/perl

@hosts = ( 'bdgpu-n02', 'bdgpu-n03', 'bdgpu-n04', 'bdgpu-n06',
	'bdgpu-n07', 'bdgpu-n08', 'bdgpu-n09', 'bdgpu-n10'
);

foreach $h ( @hosts ) {
	&submit( $h, 4 );
}

# # # # # # # # # #
 # # # # # # # # #
# # # # # # # # # #

sub submit {
	my $h = shift( @_ );
	my $t = shift( @_ );

	if( $t < 1 ) {
		$t = 1;
	}

	open( FP, ">run_many_$h.q" );
	print FP 
	   "Executable     = /bdscratch/jbp1/memrec/iohog/iohog2.pl\n"
	 . "Arguments      = -n 40\n"
	 . "Output         = run_many.$h.out\n"
	 . "Log            = run_many.$h.log\n"
	 . "Getenv         = True\n"
	 . "Requirements   = machine == \"$h.oit.duke.edu\"\n"
	 . "Notification   = error\n"
	 . "Queue\n";
	close( FP );

	open( PP, "condor_submit run_many_$h.q |" );
	while( <PP> ) {
		chomp( $_ );
		print "condor returned [$_]\n";
	}
	close( PP );

	return;
}


