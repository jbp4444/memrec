#!/usr/bin/perl
#
# this script needs to be set-uid to root

$ENV{'PATH'} = '';

#$u = $<;
#$eu = $>;
#$g = $(;
#$eg = $);
#print "walk_proc [$u,$eu,$g,$eg]\n";

$skip_uid_threshold = 100;
%skip_uid = ( 0=>1 );  # ignore/hide processes based on owner
%skip_gid = ( 0=>1 );

opendir( DP, '/proc' );
@list = grep { /^\d/ } readdir(DP);
closedir( DP );

foreach $l ( @list ) {
	@fld = stat( "/proc/$l" );
	$uid = $fld[4];
	$gid = $fld[5];
	
	if( ($uid>$skip_uid_threshold) and (! exists($skip_uid{$uid})) ) {
		if( ! exists($skip_gid{$gid}) ) {
			$exe = readlink( "/proc/$l/exe" );
			$cwd = readlink( "/proc/$l/cwd" );

			# could link in fd/* for symlinks to open files

			# for perl, python, etc. the "application" will be found in the argument list
			if( $exe =~ m/perl$/ ) {
				$exe2 = &perl_args( $l, $exe, $cwd );
			} elsif( $exe =~ m/python$/ ) {
				$exe2 = &python_args( $l, $exe, $cwd );
			} else {
				$exe2 = '';
			}

			open( PP, "/proc/$l/stat" );
			$_ = <PP>;
			$_ =~ m/\((.*?)\).*/;
			$exe3 = $1;
			close( PP );

			
			print "$l,$uid,$gid,$exe,$cwd,$exe2,$exe3\n";
		}
	}
}

# # # # # # # # # # # # # # # # # # # #
 # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # #

# TODO: how to catch '-ve foo' where v is a singleton and e has an argument?

sub perl_args {
	my $pid = shift( @_ );
	my $exe = shift( @_ );
	my $cwd = shift( @_ );
	my ($exe2,$cmdline,$i,$f);
	my @fld = ();

	$exe2 = '';
	$cmdline = '';
	
	open( PP, "/proc/$pid/cmdline" );
	while( <PP> ) {
		chomp( $_ );
		$cmdline .= $_;
	}
	close( PP );
	
	@fld = split( '\000', $cmdline );
	# i=0 is the perl command
	for($i=1;$i<scalar(@fld);$i++) {
		$f = $fld[$i];
		if( $f =~ m/^\-/ ) {
			if( $f =~ m/^\-[Ce]/ ) {
				# assume this is a multi-part command-line option
				# e.g. '-C foo'
				# .. so we skip the next arg (it is not the "second" command we're looking for)
				$i++;
			} else {
				# assume this is a standard command-line option
				# e.g. '-v' or '-abc'
			}
		} else {
			# assume the first non-dash argument is the "second" command we're looking for
			# i.e. the name of the perl/python script to run
			$exe2 = $f;
			last;
		}
	}
	
	return( $exe2 );
}

sub python_args {
	my $pid = shift( @_ );
	my $exe = shift( @_ );
	my $cwd = shift( @_ );
	my ($exe2,$cmdline,$i,$f);
	my @fld = ();

	$exe2 = '';
	$cmdline = '';
	
	open( PP, "/proc/$pid/cmdline" );
	while( <PP> ) {
		chomp( $_ );
		$cmdline .= $_;
	}
	close( PP );
	
	@fld = split( '\000', $cmdline );
	for($i=0;$i<scalar(@fld);$i++) {
		$f = $fld[$i];
		if( $f =~ m/^\-/ ) {
			# assume this is a standard command-line option
			# e.g. '-v' or '-abc'
		} else {
			# assume the first non-dash argument is a "major" argument
			# i.e. the name of the perl/python script to run
			$exe2 = $f;
		}
	}
	
	return( $exe2 );
}
