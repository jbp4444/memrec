#!/usr/bin/perl
#
# (C) 2012, John Pormann, Duke University
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
# RCSID $Id: $

package nfscli;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;
use wrapctr;

# /proc/net/rpc/nfs:
# net 0 0 0 0
# rpc 25495640 0 0
# proc2 18 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
# proc3 22 0 6868188 233380 2469849 1316457 817 7234587 4422031 126800 7922 1889 0 
#     ... 174215 7796 42695 359 271997 2203835 111207 1598 0 0
# proc4 36 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0

# proc# == NFS version

# almost equal to above:  nfsstat:
# Client rpc stats:
# calls      retrans    authrefrsh
# 25495640   0          0       
# Client nfs v3:
# null         getattr//3      setattr//4      lookup//5       access//6       readlink//7     
# 0         0% 6868188  26%    233380    0%    2469849   9%    1316457   5%    817       0% 
# read//8         write//9        create//10       mkdir//11        symlink//12      mknod//13        
# 7234587  28%    4422031  17%    126800    0%     7922      0%     1889      0%     0         0% 
# remove       rmdir        rename       link         readdir      readdirplus  
# 174215    0% 7796      0% 42695     0% 359       0% 271997    1% 2203835   8% 
# fsstat       fsinfo       pathconf     commit       
# 111207    0% 1598      0% 0         0% 0         0% 

sub prep {
}

sub new {
	my $class = shift;
	my $self = {};
	my ( $i, $fp, $meta, $read, $write );
	my @fld = ();
	
	$meta = 0;
	$read = 0;
	$write = 0;
	
	open( $fp, '/proc/net/rpc/nfs' )
		or print STDERR "** Error: cannot open file [/proc/net/rpc/nfs]\n";
	while( <$fp> ) {
		if( $_ =~ m/^proc3/ ) {
			@fld = split( /\s+/, $_ );
			for($i=3;$i<scalar(@fld);$i++) {
				$self->{"ctr_$i"} = wrapctr->new( $fld[$i] );
			}
			last;
		}
	}	
	
	$self->{'fp'}    = $fp;
	$self->{'last_tstamp'} = 0;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ($i, $delta_read, $delta_write, $delta_meta );
	my $fp = $self->{'fp'};
	my $tstamp      = $dref->{'tstamp'};
	my $last_tstamp = $self->{'last_tstamp'};
	my @delta = ();

	if( $last_tstamp == $tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero
		$last_tstamp = $tstamp - 1;
	}

	seek( $fp, 0, 0 );

	while (<$fp>) {
		if( $_ =~ m/^proc3/ ) {
			@fld = split( /\s+/, $_ );
			for($i=3;$i<scalar(@fld);$i++) {
				$delta[$i] = $self->{"ctr_$i"}->update( $fld[$i] );
			}
			last;
		}
	}	

	$delta_read = $delta[8];
	$delta_write = $delta[9];
	$delta_meta = 0;
	for($i=3;$i<scalar(@delta);$i++) {
		$delta_meta += $delta[$i];
	}
	$delta_meta -= ($delta_read+$delta_write);
	
	$dref->{'nfs_meta'}  = &round00( $delta_meta / ($tstamp - $last_tstamp) );
	$dref->{'nfs_read'}  = &round00( $delta_read / ($tstamp - $last_tstamp) );
	$dref->{'nfs_write'} = &round00( $delta_write / ($tstamp - $last_tstamp) );
	
	$self->{'last_tstamp'} = $tstamp;
	
	return( 0 );	
}

sub delete {
	my $self = shift;
	
	# could be nice and clean-up all the wrapctrs
	# for now, we'll let the garbage collector handle that
	
	close( $self->{'fp'} );
}

1;
