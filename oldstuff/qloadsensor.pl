#!/usr/bin/perl
#
# (C) 2004-2011, John Pormann, Duke University
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
# RCSID: $Id: qloadsensor.pl 407 2012-04-18 20:19:09Z jbp $
#
# qloadsensor - SGE load-sensor

use strict;

my $config_file = '/etc/qloadsensor.conf';

my $df_cmd      = '/bin/df';
my $ping_cmd    = '/bin/ping';
my $ping_host   = 'monitor1';
my $ypmatch_cmd = '/usr/bin/ypmatch';
my $dmesg_cmd   = '/bin/dmesg';
my $vendor_file = '/etc/duke/vendor';
my $model_file  = '/etc/duke/model';
my $osrev_file  = '/etc/redhat-release';
my $qlv_file   = '/etc/duke/qloadvals';

# config for IPMItool
my %ipmitool_cmd = (
	default                    => '/usr/bin/ipmitool',
	# need Dell-specific ipmitool exe only for 'powermonitor status'
	'Dell Inc. PowerEdge R610' => '/usr/bin/ipmitool-dell',
	'Dell Inc. PowerEdge M600' => '/usr/bin/ipmitool-dell',
	'Dell Inc. PowerEdge M610' => '/usr/bin/ipmitool-dell'
);
my $ipmi_timeout = 15;             # seconds
my $wattsup_cmd  = '/admin/reports/bin/wattsup';

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

# necessary constants
my $ULONG_MAX = ( ~0 );

# read config file (for IPMI username/password)
open( FP, $config_file );
while (<FP>) {
	chomp($_);
	if ( $_ =~ m/^ping_host\s*\=/ ) {
		$ping_host = $_;
		$ping_host =~ s/(.*?)\=\s*//;
	}
	elsif ( $_ =~ m/^ipmi_timeout\s*/ ) {
		$ipmi_timeout = $_;
		$ipmi_timeout =~ s/(.*?)\=\s*//;
		$ipmi_timeout += 0;
	}
}
close(FP);

# find this host's name
# : another way to do this: `$root_dir/utilbin/$myarch/gethostname -name`
my $hostname = `uname -n`;
chomp($hostname);
# : trim off any .foo.bar.baz stuff
$hostname =~ s/(.*?)\.(.*)/$1/;

# force a flush of the print buffer for every line
# : otherwise the pipe from SGE execd won't work !!
$| = 1;

&init_cpuinfo();
&init_hostmodel();
&init_net_dev();
&init_diskstats();
&init_df_scratch();
&init_ipmitool();
&init_sge_shep();
&init_ping();
&init_qloadvals();

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $last_tstamp = time;
my $tstamp;

#
# MAIN LOOP
while (1) {
	my $x = <STDIN>;
	if ( $x =~ m/^quit/ ) {
		exit(0);
	}

	$tstamp = time;

	if ( $tstamp == $last_tstamp ) {
		#
		# MAJOR KLUDGE to avoid div-by-zero errors
		$tstamp++;
	}

	print "begin\n";

	&next_cpuinfo();
	&next_hostmodel();
	&next_net_dev();
	&next_diskstats();
	&next_df_scratch();
	&next_ipmitool();
	&next_sge_shep();
	&next_ping();
	&next_qloadvals();

	print "end\n";

	$last_tstamp = $tstamp;
}

&exit_cpuinfo();
&exit_hostmodel();
&exit_net_dev();
&exit_diskstats();
&exit_df_scratch();
&exit_ipmitool();
&exit_sge_shep();
&exit_ping();
&exit_qloadvals();

exit(0);

# # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub delta {
	my $x = shift(@_);
	my $y = shift(@_);
	my ($d);
	if ( $x >= $y ) {
		$d = $x - $y;
	}
	else {

		# OVERFLOW
		$d = ( $ULONG_MAX - $y ) + $x;
	}
	return ($d);
}

#
# for basic CPU info
BEGIN {
	my $mhz     = 0.0;
	my $model   = 'generic-cpu';
	my $modeln  = '0.0.0';
	my $centos5 = 0;

	#my $bogomips = 0.0;
	sub init_cpuinfo {
		my ( $cpufam, $cpumod, $cpustep );
		open( FP, '/proc/cpuinfo' )
		  or print "** Error: cannot open file [/proc/cpuinfo]\n";
		while (<FP>) {
			if ( $_ =~ m/^cpu mhz/i ) {
				$mhz = $_;
				$mhz =~ s/cpu mhz\s*\:\s*(.*)/$1/i;

				# round mhz to nearest 50mhz
				$mhz = 50 * int( ( $mhz + 25 ) / 50 );

				#} elsif( $_ =~ m/^bogomips/i ) {
				#  $bogomips = $_;
				#  $bogomips =~ s/bogomips\s*\:\s*(.*)/$1/i;
				#  # round mhz to nearest unit
				#  $bogomips = int( $bogomips + 0.5 );
			}
			elsif ( $_ =~ m/^model\s+name/i ) {
				chomp($_);
				$model = lc($_);
				$model =~ s/model\s+name\s*\:\s*(.*)/$1/i;
				$model =~ s/\(r\)//g;
				$model =~ s/\(tm\)//g;
				$model =~ s/cpu//;
				$model =~ s/processor//;
				$model =~ s/\@.*//;
				$model =~ s/\w+\-core//;
				$model =~ s/\d+\.\d+ghz//;
				$model =~ s/^\s+//;
				$model =~ s/\s+$//;
				$model =~ s/\s+/-/g;
			}
			elsif ( $_ =~ m/^cpu\s+family/i ) {
				$cpufam = $_;
				$cpufam =~ s/cpu\s+family\s*\:\s*(.*)/$1/i;
				$cpufam += 0;
			}
			elsif ( $_ =~ m/^model/i ) {
				$cpumod = $_;
				$cpumod =~ s/model\s*\:\s*(.*)/$1/i;
				$cpumod += 0;
			}
			elsif ( $_ =~ m/^stepping/i ) {
				$cpustep = $_;
				$cpustep =~ s/stepping\s*\:\s*(.*)/$1/i;
				$cpustep += 0;
			}
		}
		close(FP);
		$modeln = $cpufam . '.' . $cpumod . '.' . $cpustep;
		open( FP, $osrev_file );
		$centos5 = <FP>;
		close(FP);
		if ( $centos5 =~ m/centos(.*?)5\./i ) {
			$centos5 = 1;
		}
		else {
			$centos5 = 0;
		}
	}

	sub next_cpuinfo {
		print "$hostname:mhz:$mhz\n"
		  . "$hostname:cpumodel:$model\n"
		  . "$hostname:cpumodeln:$modeln\n";
		#  . "$hostname:bogomips:$bogomips\n";
		if( $centos5 > 0 ) {
		  print "$hostname:centos5:$centos5\n";
		}
	}

	sub exit_cpuinfo {
		# nothing to do
	}
}

#
# for Duke-specific vendor/model info
BEGIN {
	my $hostmodel = 'generic-host';

	sub init_hostmodel {
		my ( $vendor, $model, $k, $flag );
		$flag = 0;
		open( FP, $vendor_file ) or $flag = 1;
		if ($flag) {
			print "** Error: cannot open file [$vendor_file]\n";
			$vendor = 'unknown';
		}
		else {
			$_ = <FP>;
			chomp($_);
			$vendor = lc($_);
			close(FP);

			# we only need the vendors first name (Dell, Sun, IBM, etc.)
			$vendor =~ s/(.*?)\s+(.*)/$1/;
			$vendor =~ s/,//g;
		}
		$flag = 0;
		open( FP, $model_file ) or $flag = 1;
		if ($flag) {
			print "** Error: cannot open file [$model_file]\n";
			$model = 'unknown';
		}
		else {
			$_ = <FP>;
			chomp($_);
			$model = lc($_);
			close(FP);

			# we can ignore some of the model name too
			$model =~ s/sun fire//;
			$model =~ s/poweredge//;
			$model =~ s/virtual platform//;
			$model =~ s/\s+//g;
		}
		$hostmodel = $vendor . ' ' . $model;
		$hostmodel =~ s/\s*$//;
		$hostmodel =~ s/\s+/ /g;
		$hostmodel =~ s/ /-/g;
	}

	sub next_hostmodel {
		print "$hostname:hostmodel:$hostmodel\n";
	}

	sub exit_hostmodel {
		# nothing to do
	}
}

#
# for Network I/O
BEGIN {
	my $num_eth             = 0;
	my @last_bytes_in       = ();
	my @last_bytes_out      = ();
	my @last_packets_in     = ();
	my @last_packets_out    = ();
	my @last_packeterrs_in  = ();
	my @last_packeterrs_out = ();

	sub init_net_dev {
		my ($e);
		my @fld = ();
		open( FPnd, '/proc/net/dev' )
		  or print "** Error: cannot open file [/proc/net/dev]\n";
		$num_eth = 0;
		while (<FPnd>) {
			if ( $_ =~ m/eth(\d)\:(.*)/ ) {
				$e                    = $1 + 0;
				@fld                  = split( /\s+/, $2 );
				$last_bytes_in[$e]    = $fld[0];
				$last_bytes_out[$e]   = $fld[8];
				$last_packets_in[$e]  = $fld[1];
				$last_packets_out[$e] = $fld[9];

		# field 2/10==packet errs, 3/11==drops, 4/12==fifo errs, 5/13=frame errs
				$last_packeterrs_in[$e] = $fld[2] + $fld[3] + $fld[4] + $fld[5];
				$last_packeterrs_out[$e] =
				  $fld[10] + $fld[11] + $fld[12] + $fld[13];
				$num_eth++;
			}
		}
	}

	sub next_net_dev {
		my @bytes_in       = ();
		my @bytes_out      = ();
		my @packets_in     = ();
		my @packets_out    = ();
		my @packeterrs_in  = ();
		my @packeterrs_out = ();
		my ( $e, $delta_bytes_in, $delta_bytes_out, $delta_packets_in,
			$delta_packets_out, $delta_packeterrs_in, $delta_packeterrs_out );
		my (
			$bytes_in_persec,      $bytes_out_persec,
			$packets_in_persec,    $packets_out_persec,
			$packeterrs_in_persec, $packeterrs_out_persec
		);
		my @fld = ();
		seek( FPnd, 0, 0 );

		while (<FPnd>) {
			if ( $_ =~ m/eth(\d)\:(.*)/ ) {
				$e                  = $1 + 0;
				@fld                = split( /\s+/, $2 );
				$bytes_in[$e]       = $fld[0];
				$bytes_out[$e]      = $fld[8];
				$packets_in[$e]     = $fld[1];
				$packets_out[$e]    = $fld[9];
				$packeterrs_in[$e]  = $fld[2] + $fld[3] + $fld[4] + $fld[5];
				$packeterrs_out[$e] = $fld[10] + $fld[11] + $fld[12] + $fld[13];
			}
		}
		$delta_bytes_in       = 0;
		$delta_bytes_out      = 0;
		$delta_packets_in     = 0;
		$delta_packets_out    = 0;
		$delta_packeterrs_in  = 0;
		$delta_packeterrs_out = 0;
		for ( $e = 0 ; $e < $num_eth ; $e++ ) {
			$delta_bytes_in  += &delta( $bytes_in[$e],  $last_bytes_in[$e] );
			$delta_bytes_out += &delta( $bytes_out[$e], $last_bytes_out[$e] );
			$delta_packets_in += &delta( $packets_in[$e], $last_packets_in[$e] );
			$delta_packets_out += &delta( $packets_out[$e], $last_packets_out[$e] );
			$delta_packeterrs_in += &delta( $packeterrs_in[$e], $last_packeterrs_in[$e] );
			$delta_packeterrs_out += &delta( $packeterrs_out[$e], $last_packeterrs_out[$e] );
		}
		$bytes_in_persec    = $delta_bytes_in   / ( $tstamp - $last_tstamp );
		$bytes_out_persec   = $delta_bytes_in   / ( $tstamp - $last_tstamp );
		$packets_in_persec  = $delta_packets_in / ( $tstamp - $last_tstamp );
		$packets_out_persec = $delta_packets_in / ( $tstamp - $last_tstamp );
		$packeterrs_in_persec = $delta_packeterrs_in / ( $tstamp - $last_tstamp );
		$packeterrs_out_persec = $delta_packeterrs_in / ( $tstamp - $last_tstamp );
		printf "$hostname:bytes_in:%.2f\n"
		  . "$hostname:bytes_out:%.2f\n"
		  . "$hostname:packets_in:%.2f\n"
		  . "$hostname:packets_out:%.2f\n"
		  . "$hostname:packeterrs_in:%.2f\n"
		  . "$hostname:packeterrs_out:%.2f\n", $bytes_in_persec,
		  $bytes_out_persec, $packets_in_persec, $packets_out_persec,
		  $packeterrs_in_persec, $packeterrs_out_persec;

		for ( $e = 0 ; $e < $num_eth ; $e++ ) {
			$last_bytes_in[$e]       = $bytes_in[$e];
			$last_bytes_out[$e]      = $bytes_out[$e];
			$last_packets_in[$e]     = $packets_in[$e];
			$last_packets_out[$e]    = $packets_out[$e];
			$last_packeterrs_in[$e]  = $packeterrs_in[$e];
			$last_packeterrs_out[$e] = $packeterrs_out[$e];
		}
	}

	sub exit_net_dev {
		close(FPnd);
	}
}

#
# for Disk I/O
BEGIN {
	my $num_partitions  = 0;
	my $num_swap        = 0;
	my @is_swap         = ();
	my @last_num_rd     = ();
	my @last_num_wr     = ();
	my @last_sectors_rd = ();
	my @last_sectors_wr = ();
	my %part_map        = ();

	sub init_diskstats {
		my ( $c, $n );
		my @fld = ();
		open( FPds, '/proc/diskstats' )
		  or print "** Error: cannot open file [/proc/diskstats]\n";
		$c = 0;
		while (<FPds>) {
			if ( $_ =~ m/\s+([sh]d\w\d)\s+/ ) {
				$n                   = $1;
				@fld                 = split( /\s+/, $_ );
				$last_num_rd[$c]     = $fld[4];
				$last_num_wr[$c]     = $fld[8];
				$last_sectors_rd[$c] = $fld[6];
				$last_sectors_wr[$c] = $fld[10];
				$is_swap[$c]         = 0;
				$part_map{$n}        = $c;
				$c++;
			}
		}
		$num_partitions = $c;

		# : now, what partitions are swap?
		$num_swap = 0;
		open( FPsw, '/proc/swaps' )
		  or print "** Error: cannot open file [/proc/swaps]\n";
		while (<FPsw>) {
			if ( $_ =~ m/\/([sh]d\w\d)\s+/ ) {
				$n = $part_map{$1};
				$is_swap[$n] = 1;
				$num_swap++;
			}
		}
		close(FPsw);
	}

	sub next_diskstats {
		#
		# disk stats
		my @num_rd     = ();
		my @num_wr     = ();
		my @sectors_rd = ();
		my @sectors_wr = ();
		my ( $c, $delta_num_rd, $delta_num_wr, $delta_sectors_rd,
			$delta_sectors_wr );
		my (
			$delta_sw_num_rd,     $delta_sw_num_wr,
			$delta_sw_sectors_rd, $delta_sw_sectors_wr
		);
		my (
			$num_rd_persec,     $num_wr_persec,
			$sectors_rd_persec, $sectors_wr_persec
		);
		my (
			$sw_num_rd_persec,     $sw_num_wr_persec,
			$sw_sectors_rd_persec, $sw_sectors_wr_persec
		);
		my @fld = ();
		$c = 0;
		seek( FPds, 0, 0 );

		while (<FPds>) {
			if ( $_ =~ m/\s+([sh]d\w\d)\s+/ ) {
				@fld = split( /\s+/, $_ );
				$num_rd[$c]     = $fld[4];
				$num_wr[$c]     = $fld[8];
				$sectors_rd[$c] = $fld[6];
				$sectors_wr[$c] = $fld[10];
				$c++;
			}
		}
		$delta_num_rd        = 0;
		$delta_num_wr        = 0;
		$delta_sectors_rd    = 0;
		$delta_sectors_wr    = 0;
		$delta_sw_num_rd     = 0;
		$delta_sw_num_wr     = 0;
		$delta_sw_sectors_rd = 0;
		$delta_sw_sectors_wr = 0;

		for ( $c = 0 ; $c < $num_partitions ; $c++ ) {
			if ( $is_swap[$c] > 0 ) {
				$delta_sw_num_rd += &delta( $num_rd[$c], $last_num_rd[$c] );
				$delta_sw_num_wr += &delta( $num_wr[$c], $last_num_wr[$c] );
				$delta_sw_sectors_rd += &delta( $sectors_rd[$c], $last_sectors_rd[$c] );
				$delta_sw_sectors_wr += &delta( $sectors_wr[$c], $last_sectors_wr[$c] );
			}
			else {
				$delta_num_rd += &delta( $num_rd[$c], $last_num_rd[$c] );
				$delta_num_wr += &delta( $num_wr[$c], $last_num_wr[$c] );
				$delta_sectors_rd += &delta( $sectors_rd[$c], $last_sectors_rd[$c] );
				$delta_sectors_wr += &delta( $sectors_wr[$c], $last_sectors_wr[$c] );
			}
		}
		$num_rd_persec     = $delta_num_rd     / ( $tstamp - $last_tstamp );
		$num_wr_persec     = $delta_num_wr     / ( $tstamp - $last_tstamp );
		$sectors_rd_persec = $delta_sectors_rd / ( $tstamp - $last_tstamp );
		$sectors_wr_persec = $delta_sectors_wr / ( $tstamp - $last_tstamp );
		$sw_num_rd_persec  = $delta_sw_num_rd  / ( $tstamp - $last_tstamp );
		$sw_num_wr_persec  = $delta_sw_num_wr  / ( $tstamp - $last_tstamp );
		$sw_sectors_rd_persec = $delta_sw_sectors_rd / ( $tstamp - $last_tstamp );
		$sw_sectors_wr_persec = $delta_sw_sectors_wr / ( $tstamp - $last_tstamp );
		printf "$hostname:disk_rd:%.2f\n"
		  . "$hostname:disk_wr:%.2f\n"
		  . "$hostname:disk_sec_rd:%.2f\n"
		  . "$hostname:disk_sec_wr:%.2f\n"
		  . "$hostname:swap_rd:%.2f\n"
		  . "$hostname:swap_wr:%.2f\n"
		  . "$hostname:swap_sec_rd:%.2f\n"
		  . "$hostname:swap_sec_wr:%.2f\n", $num_rd_persec, $num_wr_persec,
		  $sectors_rd_persec, $sectors_wr_persec,    $sw_num_rd_persec,
		  $sw_num_wr_persec,  $sw_sectors_rd_persec, $sw_sectors_wr_persec;

		for ( $c = 0 ; $c < $num_partitions ; $c++ ) {
			$last_num_rd[$c]     = $num_rd[$c];
			$last_num_wr[$c]     = $num_wr[$c];
			$last_sectors_rd[$c] = $sectors_rd[$c];
			$last_sectors_wr[$c] = $sectors_wr[$c];
		}
	}

	sub exit_diskstats {
		close(FPds);
	}
}

#
# for Scratch disk space
BEGIN {
	sub init_df_scratch {
		# could check that /scratch exists?
		if ( not -e '/scratch' ) {
			print "** Error: no /scratch directory exists\n";
		}
		if ( not -d '/scratch' ) {
			print "** Error: /scratch is not a directory\n";
		}
	}

	sub next_df_scratch {
		my @list = ();
		my ($dffree);
		open( FP, "$df_cmd -k /scratch 2>&1 |" );

		# skip first line (header)
		<FP>;
		$_ = <FP>;
		close(FP);
		@list = split( /\s+/, $_ );

		# change to bytes (from KB)
		$dffree = $list[3] * 1024;
		print "$hostname:scr_free:$dffree\n";
	}

	sub exit_df_scratch {
		# nothing to do
	}
}

#
# for Power usage
BEGIN {
	my $cmd1;
	my $cmd2;
	my $wu_flag;

	sub init_ipmitool {
		my ( $vendor, $model, $ipmi_cmd, $flag );

		# could check that ipmitool exists
		$flag = 0;
		open( FP, $vendor_file ) or $flag = 1;
		if ($flag) {
			print "** Error: cannot open file [$vendor_file]\n";
			$vendor = 'unknown';
		}
		else {
			$_ = <FP>;
			chomp($_);
			$vendor = $_;
			close(FP);
		}
		$flag = 0;
		open( FP, $model_file ) or $flag = 1;
		if ($flag) {
			print "** Error: cannot open file [$model_file]\n";
			$model = 'unknown';
		}
		else {
			$_ = <FP>;
			chomp($_);
			$model = $_;
			close(FP);
		}
		$wu_flag = 0;
		if ( exists( $ipmitool_cmd{"$vendor $model"} ) ) {
			$ipmi_cmd = $ipmitool_cmd{"$vendor $model"};
			$cmd1     = "$ipmi_cmd -I open sdr list 2>&1 |";

			# could check vendor for 'Dell' to kick-in the delloem pieces
			$cmd2 = "$ipmi_cmd -I open delloem powermonitor status 2>&1 |";
		}
		elsif ( -e '/dev/ttyUSB0' ) {
			# assume any ttyUSB0 must be a WattsUp meter
			$cmd1 = "$wattsup_cmd -c 1 ttyUSB0 watts 2>&1 |";
			$cmd2 = '';
			$wu_flag = 1;
		}
		else {
			$cmd1 = '';
			$cmd2 = '';
		}
	}

	sub next_ipmitool {
		my ( $watts, $kwh, $flag );
		$watts = -1.0;
		$kwh   = -1.0;
		if ( $cmd1 ne '' ) {

			# trick from Lincoln Stein's book "Network programming with Perl"
			eval {
				local $SIG{ALRM} = sub { die '__timeout__' };
				alarm($ipmi_timeout);
				open( PP, $cmd1 );
				while (<PP>) {
					if ( $_ =~ m/System Level\s+\|\s+(.*)/ ) {
						$watts = $1 + 0;
					}
					elsif ( $wu_flag and ($_ =~ m/^(\d.*)/) ) {

						# wattsup meter just prints numbers
						$watts = $1 + 0;
					}
					elsif ( $_ =~ m/^Error/ ) {
						$watts = -1.2;
					}
				}
				close(PP);
				alarm(0);
			};
			if ( $@ =~ m/__timeout__/ ) {
				$watts = -1.3;
			}
		}
		if ( $cmd2 ne '' ) {
			eval {
				local $SIG{ALRM} = sub { die '__timeout__' };
				alarm($ipmi_timeout);
				open( PP, $cmd2 );
				$flag = 0;
				while (<PP>) {
					if ( $flag == 1 ) {
						if ( $_ =~ m/Reading\s+\:\s+(.*)/ ) {
							$kwh  = $1 + 0;
							$flag = 0;
						}
					}
					elsif ( $_ =~ m/Statistic\s+\:\s+Energy Consumption/ ) {
						$flag = 1;
					}
					elsif ( $_ =~ m/^Error/ ) {
						$kwh = -1.4;
					}
				}
				close(PP);
				alarm(0);
			};
			if ( $@ =~ m/__timeout__/ ) {
				$kwh = -1.5;
			}
		}
		printf "$hostname:watts:%.2f\n" . "$hostname:kwh:%.2f\n", $watts, $kwh;
	}

	sub exit_ipmitool {
	}
}

#
# for SGE shepherd instances (jobs)
BEGIN {
	sub init_sge_shep {
		opendir( DPss, '/proc' )
		  or print "** Error: cannot open file [/proc]\n";
	}

	sub next_sge_shep {
		my ( $count, $l, $x );
		my @list = ();
		rewinddir(DPss);
		@list = grep { /^\d/ } readdir(DPss);
		$count = 0;
		foreach $l (@list) {
			open( FPss, "/proc/$l/stat" );
			$x = <FPss>;
			close(FPss);
			if ( $x =~ m/\(sge_shepherd\)/ ) {
				$count++;
			}
		}
		print "$hostname:jobs:$count\n";
	}

	sub exit_sge_shep {
		close(DPss);
	}
}

#
# for ping response times
BEGIN {
	my $ping_ip = 'NO_PING';

	sub init_ping {
		if ( $ping_host =~ m/^\d/ ) {
			# assume ping_host is an IP-addr
			$ping_ip = $ping_host;
		}
		else {
			open( PING, "$ypmatch_cmd $ping_host hosts 2>&1 |" );
			$_ = <PING>;

			# look for an IP-addr or else error
			if ( $_ =~ m/^(\d+\.\d+\.\d+\.\d+)/ ) {
				$ping_ip = $1;
			}
			else {
				$ping_ip = 'NO_PING';
			}
			close(PING);
		}
	}

	sub next_ping {
		my ( $msec, $data );
		open( PING, "$ping_cmd -c 1 -n $ping_ip |" );
		$msec = -1;
		while (<PING>) {
			if ( $_ =~ m/bytes from(.*?)time\=(.*)/ ) {
				$data = $2;
				if ( $data =~ m/ ms/i ) {
					$msec = $data + 0;

					# } elsif( $data =~ m/ us/ ) {
					#     should try to convert units!!
				}
				else {

					# assume msec
					$msec = $data + 0;
				}
			}
			elsif ( $_ =~ m/(.) packets transmitted, (.) received/ ) {
				if ( ( $1 + 0 ) != ( $2 + 0 ) ) {
					$msec = -1;
				}
			}
		}
		close(PING);
		print "$hostname:ping:$msec\n";
	}

	sub exit_ping {
	}
}

#
# for basic info from file
BEGIN {
	my %data = ();
	
	sub init_qloadvals {
		my ( $key, $val );
		open( FP, $qlv_file )
		  or print "** Error: cannot open file [$qlv_file]\n";
		while (<FP>) {
			chomp( $_ );
			if ( $_ =~ m/^(.*?)\s*[=:]\s*(.*)/i ) {
				$key = $1;
				$val = $2;
				$key =~ s/\s/_/g;
				$val =~ s/\s/_/g;
				$data{$key} = $val;
			}
		}
		close(FP);
	}

	sub next_qloadvals {
		my ($key,$val);
		foreach $key ( keys(%data) ) {
			$val = $data{$key};
			print "$hostname:$key:$val\n";
		}
	}

	sub exit_qloadvals {
		# nothing to do
	}
}
