#!/usr/bin/perl
#
# (C) 2010-2012, John Pormann, Duke University
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
# RCSID $Id: ltrace.pm 421 2012-05-21 13:58:30Z jbp $

# TODO:
# - NOT FUNCTIONAL YET!

package ltrace;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my %funcs;
my %all_funcs = ( 'printf'=>1, 
	'malloc'=>1, 'free'=>1,
	'fopen'=>1, 'fclose'=>1, 'fwrite'=>1, 'fread'=>1
);
my $prep_done = 0;

sub prep {
	my $class = shift;
	my $prog = shift( @_ );
	my $flist = shift( @_ );
	my ($x,$k,$fcn,$pp);

	# populate %all_funcs from nm output
	if( $prog ne '' ) {
		# make sure prog is a single program (no cmd-line args)
		$prog =~ s/\s(.*)//;
		open( $pp, "/usr/bin/nm $prog |" );
		while( <$pp> ) {
			if( $_ =~ m/^\s+U\s+(.*)/ ) {
				$fcn = $1;
				$fcn =~ s/\@\@.*//;
				$all_funcs{$fcn} = 1;
			}
		}
		close( $pp );
	}
	
	# add function-names to the search-for list
	%funcs = ();
	if( ref($flist) eq 'SCALAR' ) {
		# look for 'fileops', ??
		if( $flist eq '' ) {
			%funcs = %all_funcs;
		} else {
			@fld = split( ',', $flist );
			foreach $k ( @fld ) {
				$funcs{$k} = 1;
			}
		}
	} elsif( ref($flist) eq 'HASH' ) {
		foreach $k ( %$flist ) {
			if( $k ne '' ) {
				$funcs{$k} = 1;
			}
		}
	} else {
		%funcs = %all_funcs;
	}
	
	$prep_done = 1;
	
	return;
}

sub new {
	my $class = shift;
	my $pid = shift( @_ );
	my $self = {};
	my ($fp);
	
	if( $prep_done == 0 ) {
		%funcs = %all_funcs;
	}

	# '-s 0' to NOT print strings (unfortunately, also truncates filenames)
	# '-S' to catch system calls
	open( $fp, "/usr/bin/ltrace -s 0 -S -p $pid 2>&1 |" )
		or die "cannot open ltrace to pid [$pid]\n";
	
	$self->{'pid'} = $pid;
	$self->{'fp'} = $fp;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $pid = $self->{'pid'};
	my $fp = $self->{'fp'};
	my ($x,$y,$flag,$bytes,$text,$fcn);
	my %data = ();
	my @fld = ();
	my $rfd = '';
	my $timeout = 0.1; # in sec

	foreach $x ( keys(%funcs) ) {
		$data{$x} = 0;
	}

	$flag=1;
	$rfd = '';
	vec($rfd,fileno($fp),1) = 1;
	$flag=0 unless select($rfd, undef, undef, $timeout)>0;

	#
	# process all new data items
	$text = '';
	while( $flag ) {
		$bytes = sysread( $fp, $x, 1024 );
		if( $bytes > 0 ) {
			$text .= $x;
		} else {
			$flag = 0;
			last;
		}

		$rfd = '';
		vec($rfd,fileno($fp),1) = 1;
		$flag=0 unless select($rfd, undef, undef, $timeout)>0;
	}
	
	@fld = split( "\n", $text );
	foreach $y ( @fld ) {
		$y =~ s/(\S+)\(.*//;
		$fcn = $1;
		if ( exists( $funcs{$fcn} ) ) {
			$data{$fcn}++;
		}
	}
	
	foreach $x ( keys(%funcs) ) {
		$dref->{$x} = $data{$x};
	}

	return( 0 );	
}

sub delete {
	my $self = shift;
	
	# we should probably check that ltrace has/hasn't already exitted
	
	close( $self->{'fp'} );
}

1;
