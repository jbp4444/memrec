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
# RCSID $Id: topwatch.pm 639 2013-06-20 13:42:09Z jbp $

package topwatch;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

use basesubs;

my $top_cmd = '/usr/bin/top';
my $out_type = 'keyval';
my %skip_unames = ( 'root'=>1, 'rpc'=>1, 'rpcuser'=>1, 'splunk'=>1,
	'postfix'=>1, 'dbus'=>1, 'ntp'=>1, 'nobody'=>1 );
my %skip_cmds = ( 'bash'=>1, 'tcsh'=>1, 'csh'=>1, 'sh'=>1, 'sshd'=>1 );

sub prep {
	my $class = shift( @_ );
	my $key = shift( @_ );
	my $val = shift( @_ );
	my @fld = ();
	
	if( $key eq 'skip_uid' ) {
		$skip_unames{$val} = 1;
	} elsif( $key eq 'skip_cmd' ) {
		$skip_cmds{$val} = 1;
	} elsif( $key eq 'out_type' ) {
		$out_type = $val;
	}

	return;	
}

sub new {
	my $class = shift;
	my $self  = {};
	my ($fp);
	
	# we need to create a new toprc file
	# : this shows PID Username Nice VirtuaMem ResidentMem State %CPU %MEM Parent-PID Command
	open( $fp, ">.toprc" );
	print $fp <<EOF;
RCfile for "top with windows"		# shameless braggin'
Id:a, Mode_altscr=0, Mode_irixps=1, Delay_time=3.000, Curwin=0
Def	fieldscur=AEhIOQtWKNmBcdfgjplrsuvyzX
	winflags=62777, sortindx=10, maxtasks=0
	summclr=1, msgsclr=1, headclr=3, taskclr=1
Job	fieldscur=ABcefgjlrstuvyzMKNHIWOPQDX
	winflags=62777, sortindx=0, maxtasks=0
	summclr=6, msgsclr=6, headclr=7, taskclr=6
Mem	fieldscur=ANOPQRSTUVbcdefgjlmyzWHIKX
	winflags=62777, sortindx=13, maxtasks=0
	summclr=5, msgsclr=5, headclr=4, taskclr=5
Usr	fieldscur=ABDECGfhijlopqrstuvyzMKNWX
	winflags=62777, sortindx=4, maxtasks=0
	summclr=3, msgsclr=3, headclr=2, taskclr=3
EOF
	close( $fp );
	
	$mem_total = 0;
	open( $fp, "/proc/meminfo" );
	while( <$fp> ) {
		chomp( $_ );
		if( $_ =~ m/MemTotal\:\s+(.*?)\s+(.*)/ ) {
			$mem_total = &convert_to_bytes( $1, $2 );
		}
	}
	close( $fp );

	$self->{'mem_total'} = $mem_total;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my ( $fp, $exe, $uid, $k, $v, $out, $cpu, $mem, $kmg );
	my %cpu_list = ();
	my %mem_list = ();
	my @fld = ();
	my %dup_exe = ();

	open( $fp, "unset HOME; $top_cmd -bn1 |" );
	# skip header lines
	while( <$fp> ) {
		if( $_ =~ m/PID\s+USER/ ) {
			last;
		}
	}
	while( <$fp> ) {
		chomp( $_ );
		@fld = split( /\s+/, $_ );
		if( $fld[0] eq '' ) {
			shift( @fld );
		}
		$uid = $fld[1];
		$mem = $fld[3];
		$cpu = $fld[6];
		$exe = $fld[9];

		if( exists($skip_unames{$uid}) ) {
			next;
		}
		if( exists($skip_cmds{$exe}) ) {
			next;
		}

		if( $exe eq '' ) {
			#print "found blank exe [$_]\n";
			next;
		}
		#$exe =~ s/^[\-\[]//;
		#$exe =~ s/[\:]$//;
		
		# convert mem to bytes
		# : default is kb, unless last char is otherwise
		$kmg = 'k';
		if( $mem =~ m/([kKmMgG])$/ ) {
				$kmg = $1;
		}
		$mem = &convert_to_bytes( $mem+0, $kmg );

		if( exists($dup_exe{$exe}) ) {
			$k = $dup_exe{$exe};
			$cpu_list{"$exe:$k"} = $cpu;
			$mem_list{"$exe:$k"} = $mem;
			$dup_exe{$exe}++;
		} else {
			$k = 0;
			$cpu_list{"$exe:$k"} = $cpu;
			$mem_list{"$exe:$k"} = $mem;
			$dup_exe{$exe} = 1;
		}
	}
	close( $fp );

	if( $out_type eq 'keyval' ) {
		while( ($k,$v) = each(%cpu_list) ) {
			$dref->{"cpu:$k"} = $v;
		}
		while( ($k,$v) = each(%mem_list) ) {
			$dref->{"mem:$k"} = $v;
		}
	} else {
		$out = '';
		while( ($k,$v) = each(%cpu_list) ) {
			if( $k ne '' ) {
				$out .= $k . ':' . $v . ',';
			}
		}
		$out =~ s/,$//;
		$dref->{'topwatch'} = $out;
	}

	return( 0 );
}

sub delete {

}

1;
