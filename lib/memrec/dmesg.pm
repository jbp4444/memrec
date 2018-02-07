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
# RCSID $Id: dmesg.pm 636 2013-06-12 18:19:52Z jbp $

# we really want to catch things like:
#    INFO: task pigz:15815 blocked for more than 120 seconds.
#    NFS: directory software/PredictHaplo-0.5.2 contains a readdir loop.
#    __blank__ invoked oom-killer: gfp_mask=0x280da, order=0, oom_adj=0, oom_score_adj=0
#    __blank__ segfault at c0 ip 0000003d39243d49 sp 00007fff73c40d80 error
#    bnx2 0000:04:00.0: eth0: NIC SerDes Link is Down

package dmesg;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my $dmesg_exe = '/bin/dmesg';
my %watch_list = (
	'blocked for more than 120' => 1,
	'contains a readdir loop' => 1,
	'invoked oom-killer' => 1,
	'segfault at' => 1,
	'link is down' => 1,
	'mptscsih: ioc0: task abort' => 1
);

# modify local vars
sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	
	if( lc($key) eq 'dmesg_exe' ) {
		$dmesg_exe = $val;
	} elsif( lc($key) eq 'watch' ) {
		$watch_list{$val} = 1;
	}
	
	return;
}

sub check_for_match {
	my $line = shift( @_ );
	my ( $k );
	
	foreach $k ( keys(%watch_list) ) {
		if( $line =~ m/$k/ ) {
			return( $line );
		}
	}
	
	return( '' );
}

sub new {
	my $class = shift;
	my $self = {};
	my ( $fp, $num_lines, $rtn );
	
	$num_lines = 0;
	
	# for testing
	$dmesg_exe = 'cat foo.txt';

	open( $fp, "$dmesg_exe |" )
		or print STDERR "** Error: cannot execute dmesg [$dmesg_exe]\n";
	while( <$fp> ) {
		$num_lines++;
	}
	close( $fp );
	
	$self->{'num_lines'} = $num_lines;
	
	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $old_num_lines = $self->{'num_lines'};
	my ($fp, $new_num_lines, $rtn );
	my ($ctr);

	#print "old_num_lines = $old_num_lines\n";

	$ctr = 0;
	
	open( $fp, "$dmesg_exe |" );
	while( <$fp> ) {
		chomp( $_ );
		$new_num_lines++;
		if( $new_num_lines > $old_num_lines ) {
			# maybe some new content arrived?
			$rtn = &check_for_match( $_ );
			if( $rtn ne '' ) {
				#print "match found [$rtn]\n";
				$dref->{"dmesg$ctr"} = $rtn;
				$ctr++;
			}
		}
	}
	close( $fp );

	#print "new_num_lines = $new_num_lines\n";

	$self->{'num_lines'} = $new_num_lines;

	return( 0 );	
}

sub delete {
	
}

1;
