#!/usr/bin/perl
#
# (C) 2010, John Pormann, Duke University
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
# RCSID: $Id: dscrlogger.pl 88 2011-01-04 19:23:24Z jbp $
#
# dscrlogger.pl -- perl-based daemon/monitor/logger for the DSCR
#    with syslog functionality

# TODO:
# --> virtual memory (total/used/free) ... just add mem and swap?
# --> mount-point checker (maybe only needed hourly?)
# --> running process checker (hourly?)

use Getopt::Std;
use POSIX 'setsid';
use Sys::Syslog qw( :DEFAULT );

# defaults
my $cfgfile   = 'etc_dscrlogger.cfg';
my $heartbeat = 60 * 10;
my $loglocal  = 'local4';
my $logname   = 'dscrmonitor.pl';
my $verbose   = 0;

# module-specific defaults
my $df_cmd       = '/bin/df';
my $ping_cmd     = '/bin/ping';
my $ping_ip      = '10.10.1.1';
my $scratch_dir  = '/scratch';
my $ipmitool_cmd = '/usr/bin/ipmitool';
my $timeout      = 5;

&read_cfg_file($cfgfile);

getopts('hu:l:n:p:T:C:s:vVF');

if ( defined($opt_h) ) {
	print "usage:  $0 [opts] &\n",
"  -u updatefreq     update the data every N seconds (default=$heartbeat)\n",
"  -l lognum         log number (syslog LOCAL#) for logging (default=$loglocal)\n",
	  "  -p IPaddr         IP address to ping (default=$ping_ip)\n",
	  "  -s dir            scratch dir to check (default=$scratch_dir)\n",
	  "  -T nsec           timeout for remote operations (default=$timeout)\n",
	  "  -n name           use 'name' in log info (default=$logname)\n",
	  "  -C cfgfile        set new config file (default=$cfgfile)\n",
"  -F                keep in foreground (don't daemonize, for debugging)\n",
	  "  -v                verbose\n", "  -V                really verbose\n",
	  "  reading defaults from config file [$cfgfile]\n";
	print "updatefreq can include 5m or 1h for minutes or hours\n";
	exit;
}

if ( not defined($opt_F) ) {
	$pid = fork();
	if ( $pid != 0 ) {

		# parent, should exit and return 0 error status
		$SIG{CHLD} = 'IGNORE';
		exit(0);
	}

	# from here on down, this is the child only
	chdir('/');
	setsid();
	open( STDIN,  "</dev/null" );
	open( STDOUT, ">/dev/null" );
	open( STDERR, ">&STDOUT" );
}

# turn off the signal handlers for now
$SIG{USR1} = 'IGNORE';
$SIG{USR2} = 'IGNORE';
$SIG{INT}  = 'IGNORE';

# since we use the ALARM signal to timeout of ping commands, we may
# end up with children that are waiting for ping to end, so make sure
# that we reap them when they are done
$SIG{CHLD} = 'IGNORE';

# ignore "Broken Pipe" signals so it doesn't crash the program
$SIG{PIPE} = 'IGNORE';

# check out the command line args
if ( defined($opt_u) ) {
	$heartbeat = $opt_u + 0;
	if ( $opt_u =~ m/m/i ) {
		$heartbeat *= 60;
	}
	elsif ( $opt_u =~ m/h/i ) {
		$heartbeat *= 60 * 60;
	}
}
if ( defined($opt_l) ) {
	if ( $opt_l =~ m/^local/ ) {
		$loglocal = $opt_l;
	}
	else {
		$loglocal = "local$opt_l";
	}
}
if ( defined($opt_n) ) {
	$logname = $opt_n;
}
if ( defined($opt_p) ) {
	$ping_ip = $opt_p;
}
if ( defined($opt_T) ) {
	$timeout = $opt_T;
}
if ( defined($opt_s) ) {
	$scratch_dir = $opt_s;
}
if ( defined($opt_C) ) {
	$cfgfile = $opt_C;
	&read_cfg_file($cfgfile);
}
if ( defined($opt_v) ) {
	$verbose++;
}
if ( defined($opt_V) ) {
	$verbose += 10;
}

# start up system logs
#setlogsock( 'unix' );
openlog( $logname, 'ndelay,pid', $loglocal );
syslog( "info", "daemon process starting" );

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

my $tstamp      = time();
my $last_tstamp = $tstamp;

# initialize all the sub-modules
&init_procinfo();
&init_loadavg();
&init_procstat();
&init_meminfo();
&init_netdev();
&init_diskstats();
&init_dfscratch();
&init_sge_shep();
&init_wattage();
&init_ping();

# let the counts move a little bit to avoid div-by-zero
sleep(1);

if ($verbose) {
	print "Entering main loop...\n";
}
while (1) {

	# we use time as a transaction ID
	# : just in case we get some time-skew across multiple modules
	$tstamp = time();

	# : dumb "solution" to div-by-zero issues
	if ( $last_tstamp == $tstamp ) {
		$last_tstamp--;
	}

	# call each module to get next data-item
	&next_procinfo();
	&next_procstat();
	&next_meminfo();
	&next_loadavg();
	&next_netdev();
	&next_diskstats();
	&next_dfscratch();
	&next_sge_shep();
	&next_wattage();
	&next_ping();

	# get ready to sleep for a bit
	# : first, turn on the signal handlers
	$SIG{USR1} = "handler1";
	$SIG{USR2} = "handler2";
	$SIG{INT}  = "handler3";

	$last_tstamp = $tstamp;

	sleep($heartbeat);

	# get ready for next round of data collection
	# : first, turn off the signal handlers
	$SIG{USR1} = "IGNORE";
	$SIG{USR2} = "IGNORE";
	$SIG{INT}  = "IGNORE";
}    # end-while

if ($verbose) {
	print "Exitting main loop...\n";
}

&exit_procinfo();
&exit_procstat();
&exit_meminfo();
&exit_loadavg();
&exit_netdev();
&exit_diskstats();
&exit_dfscratch();
&exit_sge_shep();
&exit_wattage();
&exit_ping();

exit;

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

sub read_cfg_file {
	my $file = shift(@_);
	my ( $x, $y );
	open( CFP, $file ) or return (-1);
	while (<CFP>) {
		chomp($_);
		if ( $_ =~ m/(heartbeat|update)\s*\=\s*(.*)/ ) {
			$heartbeat = $2 + 0;
			if ( $2 =~ m/m/i ) {
				$heartbeat *= 60;
			}
			elsif ( $2 =~ m/h/i ) {
				$heartbeat *= 60 * 60;
			}
		}
		elsif ( $_ =~ m/log_?local\s*\=\s*(.*)/ ) {
			$x = $1;
			if ( $opt_l =~ m/^local/ ) {
				$loglocal = $x;
			}
			else {
				$loglocal = "local$x";
			}
		}
		elsif ( $_ =~ m/log_?name\s*\=\s*(.*)/ ) {
			$logname = $1;
		}
		elsif ( $_ =~ m/ping_?ip\s*\=\s*(.*)/ ) {
			$ping_ip = $1;
		}
		elsif ( $_ =~ m/timeout\s*\=\s*(.*)/ ) {
			$timeout = $1 + 0;
		}
		elsif ( $_ =~ m/verbose\s*\=\s*(.*)/ ) {
			$verbose = $1 + 0;
		}
		elsif ( $_ =~ m/scratch_?dir\s*\=\s*(.*)/ ) {
			$scratch_dir = $1;
		}
		elsif ( $_ =~ m/df_?cmd\s*\=\s*(.*)/ ) {
			$df_cmd = $1;
		}
		elsif ( $_ =~ m/ping_?cmd\s*\=\s*(.*)/ ) {
			$ping_cmd = $1;
		}
		elsif ( $_ =~ m/ipmitool_?cmd\s*\=\s*(.*)/ ) {
			$ipmitool_cmd = $1;
		}
	}
	close(CFP);
	return (0);
}

sub handler1 {

	# do nothing on SIGUSR1
	# : however, this will wake up the daemon from sleep()
	#   and start a new round of data collection
}

sub handler2 {
	local $SIG{USR1} = "IGNORE";
	local $SIG{USR2} = "IGNORE";
	local $SIG{INT}  = "IGNORE";
	my ($x);

	# reload cfg file
	$x = &read_cfg_file($cfgfile);
	syslog( 'notice', "reloaded cfg file [$x]" );
}

sub handler3 {
	local $SIG{USR1} = "IGNORE";
	local $SIG{USR2} = "IGNORE";
	local $SIG{INT}  = "IGNORE";

	# we could log some info here if desired
	# then exit
	exit;
}

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

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

#
# for Linux /proc/cpuinfo
BEGIN {

	sub init_procinfo {
		my ( $mhz, $bogomips, $cpufam, $cpumod, $cpustep, $model, $modeln );
		my ( $cache_sz, $cache_al, $tlb_n, $tlb_pg );
		open( FPpi, '/proc/cpuinfo' )
		  or print "** Error: cannot open file [/proc/cpuinfo]\n";
		while (<FPpi>) {
			chomp($_);
			if ( $_ =~ m/^cpu mhz/i ) {
				$mhz = $_;
				$mhz =~ s/cpu mhz\s*\:\s*(.*)/$1/i;

				# round mhz to nearest 50mhz
				$mhz = 50 * int( ( $mhz + 25 ) / 50 );
			}
			elsif ( $_ =~ m/^bogomips/i ) {
				$bogomips = $_;
				$bogomips =~ s/bogomips\s*\:\s*(.*)/$1/i;

				# round mhz to nearest unit
				$bogomips = int( $bogomips + 0.5 );
			}
			elsif ( $_ =~ m/^model\s+name\s*\:\s*(.*)/i ) {
				$model = lc($1);
				$model =~ s/\s+/_/g;
				$model =~ s/\W//g;
				$model =~ s/_+$//;
			}
			elsif ( $_ =~ m/^cpu\s+family\s*\:\s*(.*)/i ) {
				$cpufam = $1 + 0;
			}
			elsif ( $_ =~ m/^model\s*\:\s*(.*)/i ) {
				$cpumod = $1 + 0;
			}
			elsif ( $_ =~ m/^stepping\s*\:\s*(.*)/i ) {
				$cpustep = $1 + 0;
			}
			elsif ( $_ =~ m/^tlb size\s*\:\s*(.*?)\s*(.*)/i ) {
				$tlb_n = $1 + 0;
				if ( $2 =~ m/k/i ) {
					$tlb_pg = ( $2 + 0 ) * 1024;
				}
				elsif ( $2 =~ m/m/i ) {
					$tlb_pg = ( $2 + 0 ) * 1024 * 1024;    # tlb-page in MB?
				}
				else {

					# tlb-page size is in bytes ??
					$tlb_pg = $2 + 0;
				}
			}
			elsif ( $_ =~ m/^cache size\s*\:\s*(.*?)\s*(.*)/i ) {
				$cache_sz = $1 + 0;
				if ( $2 =~ m/kb/i ) {
					$cache_sz *= 1024;
				}
				elsif ( $2 =~ m/mb/i ) {
					$cache_sz *= 1024 * 1024;    # cache in MB?
				}
				else {

					# cache size is in bytes ??
				}
			}
			elsif ( $_ =~ m/^cache_alignment\s*\:\s*(.*)/i ) {
				$cache_al = $1 + 0;
			}

		}
		close(FPpi);
		$modeln = $cpufam . '.' . $cpumod . '.' . $cpustep;
		syslog( 'notice',
			    "mhz=$mhz model=$model modeln=$modeln bogomips=$bogomips "
			  . "cache_sz=$cache_sz cache_align=$cache_al tlb_num=$tlb_n tlb_page=$tlb_pg"
		);
	}

	sub next_procinfo {
	}

	sub exit_procinfo {
	}
}

#
# for Linux load average (1/5/15 min)
BEGIN {

	sub init_loadavg {
		open( FPla, '/proc/loadavg' );
	}

	sub next_loadavg {
		my ( $x, $y, $z, $xtra );
		seek( FPla, 0, 0 );
		$_ = <FPla>;
		( $x, $y, $z, $xtra ) = split( /\s+/, $_ );
		syslog( 'notice', "xid=$tstamp load1=$x load5=$y load15=$z" );
	}

	sub exit_loadavg {
		close(FPla);
	}
}

#
# for memory usage
BEGIN {
	sub init_meminfo {
		open( FPmi, '/proc/meminfo' );
	}
	
	sub next_meminfo {
		my ( $x, $m_total, $m_used, $m_free, $s_total, $s_used, $s_free );
		$m_total = 1;
		$m_free  = 0;
		$s_total = 1;
		$s_free  = 0;
		seek( FPmi, 0, 0 );
		while( <FPmi> ) {
			chomp( $_ );
			if( $_ =~ m/MemTotal\:\s*(.*)/ ) {
				$x = $1;
				if( $x =~ m/mb/i ) {
					# convert mb to kb
					$m_total = 1024*( $x + 0 );
				} elsif( $x =~ m/kb/i ) {
					$m_total = $x + 0;
				} else {
					$m_total = $x + 0;
				}
			} elsif( $_ =~ m/MemFree\:\s*(.*)/ ) {
				$x = $1;
				if( $x =~ m/mb/i ) {
					# convert mb to kb
					$m_free = 1024*( $x + 0 );
				} elsif( $x =~ m/kb/i ) {
					$m_free = $x + 0;
				} else {
					$m_free = $x + 0;
				}
			} elsif( $_ =~ m/SwapTotal\:\s*(.*)/ ) {
				$x = $1;
				if( $x =~ m/mb/i ) {
					# convert mb to kb
					$s_total = 1024*( $x + 0 );
				} elsif( $x =~ m/kb/i ) {
					$s_total = $x + 0;
				} else {
					$s_total = $x + 0;
				}
			} elsif( $_ =~ m/SwapFree\:\s*(.*)/ ) {
				$x = $1;
				if( $x =~ m/mb/i ) {
					# convert mb to kb
					$s_free = 1024*( $x + 0 );
				} elsif( $x =~ m/kb/i ) {
					$s_free = $x + 0;
				} else {
					$s_free = $x + 0;
				}
			}
		} # last line in file
		$m_used = $m_total - $m_free;
		$s_used = $s_total - $s_free;
		syslog( 'notice', "xid=$tstamp mem_total=$m_total mem_free=$m_free mem_used=$m_used "
		     .  "swap_total=$s_total swap_free=$s_free swap_used=$s_used" );
	}
	
	sub exit_meminfo {
		close( FPmi );
	}
}

#
# for cpu usage info (/proc/stat)
BEGIN {
	my $num_cpus  = 0;
	my %prev_data = ();

	sub init_procstat {
		my ($e);
		my @fld = ();
		open( FPst, '/proc/stat' )
		  or print "** Error: cannot open file [/proc/stat]\n";
		$num_cpus = 0;
		while (<FPst>) {
			if ( $_ =~ m/cpu\s+(.*)/ ) {
				my @fld = ();
				@fld = split( /\s+/, $2 );
				$prev_data{'ttl'} = \@fld;
			}
			elsif ( $_ =~ m/cpu(\d)\s+(.*)/ ) {
				my @fld = ();
				$e             = $1 + 0;
				@fld           = split( /\s+/, $2 );
				$prev_data{$e} = \@fld;
				$num_cpus++;
			}
		}
	}

	sub next_procstat {
		my ( $x, $y, $cp, $pp, $k, $kk, $txt );
		my @fld        = ();
		my %curr_data  = ();
		my %delta_data = ();
		seek( FPst, 0, 0 );
		while (<FPst>) {
			if ( $_ =~ m/cpu\s+(.*)/ ) {
				my @fld = ();
				@fld = split( /\s+/, $1 );
				$curr_data{'ttl'} = \@fld;
			}
			elsif ( $_ =~ m/cpu(\d)\s+(.*)/ ) {
				my @fld = ();
				$x             = $1 + 0;
				@fld           = split( /\s+/, $2 );
				$curr_data{$x} = \@fld;
			}
			else {
				last;
			}
		}
		foreach $k ( keys(%curr_data) ) {
			my @fld = ();
			$cp = $curr_data{$k};
			$pp = $prev_data{$k};
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$fld[$kk] = &delta( $cp->[$kk], $pp->[$kk] );
			}
			$delta_data{$k} = \@fld;
		}
		$txt = "xid=$tstamp ";
		$cp  = $delta_data{'ttl'};
		$x   = $cp->[3];
		$y   = 0;
		for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
			$y += $cp->[$kk];
		}
		$x = int( 100.0 - 100.0 * $x / $y );
		$txt .= "cpu=$x ";
		foreach $k ( sort( keys(%curr_data) ) ) {
			if ( $k eq 'ttl' ) {
				next;
			}
			$cp = $delta_data{$k};
			$x  = $cp->[3];
			$y  = 0;
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$y += $cp->[$kk];
			}
			$x = int( 100.0 - 100.0 * $x / $y );
			$txt .= "cpu$k=$x ";
		}
		syslog( 'notice', $txt );

		foreach $k ( keys(%curr_data) ) {
			$cp = $curr_data{$k};
			$pp = $prev_data{$k};
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$pp->[$kk] = $cp->[$kk];
			}
		}
	}

	sub exit_procstat {
		close(FPst);
	}
}

#
# for Network I/O
BEGIN {
	my $num_eth   = 0;
	my %prev_data = ();

	sub init_netdev {
		my ( $e, $i );
		my @fld     = ();
		my @fld_ttl = ();
		open( FPnd, '/proc/net/dev' )
		  or print "** Error: cannot open file [/proc/net/dev]\n";
		$num_eth = 0;
		for ( $i = 0 ; $i < 16 ; $i++ ) {
			$fld_ttl[$i] = 0;
		}
		while (<FPnd>) {
			if ( $_ =~ m/eth(\d)\:(.*)/ ) {
				$e             = $1 + 0;
				@fld           = split( /\s+/, $2 );
				$prev_data{$e} = \@fld;
				$num_eth++;
				for ( $i = 0 ; $i < scalar(@fld) ; $i++ ) {
					$fld_ttl[$i] += $fld[$i];
				}
			}
		}
		$prev_data{'ttl'} = \@fld_ttl;
	}

	sub next_netdev {
		my ( $x, $y, $z, $cp, $pp, $k, $kk, $txt );
		my (
			$bytes_in_persec,      $bytes_out_persec,
			$packets_in_persec,    $packets_out_persec,
			$packeterrs_in_persec, $packeterrs_out_persec
		);
		my @fld        = ();
		my @fld_ttl    = ();
		my %curr_data  = ();
		my %delta_data = ();
		for ( $i = 0 ; $i < 16 ; $i++ ) {
			$fld_ttl[$i] = 0;
		}
		seek( FPnd, 0, 0 );
		while (<FPnd>) {
			if ( $_ =~ m/eth(\d)\:(.*)/ ) {
				$x             = $1 + 0;
				@fld           = split( /\s+/, $2 );
				$curr_data{$x} = \@fld;
				for ( $i = 0 ; $i < scalar(@fld) ; $i++ ) {
					$fld_ttl[$i] += $fld[$i];
				}
			}
		}
		$curr_data{'ttl'} = \@fld_ttl;
		foreach $k ( keys(%curr_data) ) {
			my @fld = ();
			$cp = $curr_data{$k};
			$pp = $prev_data{$k};
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$fld[$kk] = &delta( $cp->[$kk], $pp->[$kk] );
			}
			$delta_data{$k} = \@fld;
		}
		foreach $k ( keys(%delta_data) ) {
			$cp                   = $delta_data{$k};
			$bytes_in_persec      = $cp->[0] / ( $tstamp - $last_tstamp );
			$packets_in_persec    = $cp->[1] / ( $tstamp - $last_tstamp );
			$packeterrs_in_persec =
			  ( $cp->[2] + $cp->[3] + $cp->[4] + $cp->[5] + $cp->[6] + $cp->[7]
			  ) / ( $tstamp - $last_tstamp );
			$bytes_out_persec   = $cp->[8] / ( $tstamp - $last_tstamp );
			$packets_out_persec = $cp->[9] / ( $tstamp - $last_tstamp );
			$packeterrs_out_persec =
			  ( $cp->[10] + $cp->[11] + $cp->[12] + $cp->[13] + $cp->[14] +
				  $cp->[15] ) / ( $tstamp - $last_tstamp );
			if ( $k eq 'ttl' ) {
				$y = '';
			}
			else {
				$y = $k;
			}
			$x = sprintf(
				"xid=$tstamp eth${y}_bytes_in=%.2f eth${y}_bytes_out=%.2f "
				  . "eth${y}_packets_in=%.2f eth${y}_packets_out=%.2f "
				  . "eth${y}_packeterrs_in=%.2f eth${y}_packeterrs_out=%.2f",
				$bytes_in_persec,      $bytes_out_persec,
				$packets_in_persec,    $packets_out_persec,
				$packeterrs_in_persec, $packeterrs_out_persec
			);
			syslog( 'notice', $x );
		}

		foreach $k ( keys(%curr_data) ) {
			$cp = $curr_data{$k};
			$pp = $prev_data{$k};
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$pp->[$kk] = $cp->[$kk];
			}
		}
	}

	sub exit_netdev {
		close(FPnd);
	}
}

#
# for Disk I/O
BEGIN {
	my $num_partitions = 0;
	my $num_swap       = 0;
	my %is_swap        = ();
	my %prev_data      = ();

	sub init_diskstats {
		my ( $x, $y );
		my @fld = ();

		# : what partitions are swap?
		$num_swap = 0;
		open( FPds, '/proc/swaps' )
		  or print "** Error: cannot open file [/proc/swaps]\n";
		while (<FPds>) {
			if ( $_ =~ m/\/([sh]d\w\d)\s+/ ) {
				$is_swap{$1} = 1;
				$num_swap++;
			}
		}
		close(FPds);
		$num_partitions = 0;
		open( FPds, '/proc/diskstats' )
		  or print "** Error: cannot open file [/proc/diskstats]\n";
		while (<FPds>) {
			if ( $_ =~ m/\s+([sh]d\w\d)\s+(.*)/ ) {
				my @fld = ();
				$x             = $1;
				@fld           = split( /\s+/, $2 );
				$prev_data{$x} = \@fld;
				$is_swap{$x} += 0;    # make sure entries are 0 or 1
				$num_partitions++;
			}
		}

	}

	sub next_diskstats {
		my ( $x, $c );
		my (
			$delta_num_rd,        $delta_num_wr,    $delta_sectors_rd,
			$delta_sectors_wr,    $delta_sw_num_rd, $delta_sw_num_wr,
			$delta_sw_sectors_rd, $delta_sw_sectors_wr
		);
		my @fld        = ();
		my %curr_data  = ();
		my %delta_data = ();

		seek( FPds, 0, 0 );
		while (<FPds>) {
			if ( $_ =~ m/\s+([sh]d\w\d)\s+(.*)/ ) {
				my @fld = ();
				$x             = $1;
				@fld           = split( /\s+/, $2 );
				$curr_data{$x} = \@fld;
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

		foreach $x ( keys(%curr_data) ) {
			$cp = $curr_data{$x};
			$pp = $prev_data{$x};
			if ( $is_swap{$x} > 0 ) {
				$delta_sw_num_rd     += &delta( $cp->[0], $pp->[0] );
				$delta_sw_num_wr     += &delta( $cp->[4], $pp->[4] );
				$delta_sw_sectors_rd += &delta( $cp->[2], $pp->[2] );
				$delta_sw_sectors_wr += &delta( $cp->[6], $pp->[6] );
			}
			else {
				$delta_num_rd     += &delta( $cp->[0], $pp->[0] );
				$delta_num_wr     += &delta( $cp->[4], $pp->[4] );
				$delta_sectors_rd += &delta( $cp->[2], $pp->[2] );
				$delta_sectors_wr += &delta( $cp->[6], $pp->[6] );
			}
		}
		$delta_num_rd     = $delta_num_rd /     ( $tstamp - $last_tstamp );
		$delta_num_wr     = $delta_num_wr /     ( $tstamp - $last_tstamp );
		$delta_sectors_rd = $delta_sectors_rd / ( $tstamp - $last_tstamp );
		$delta_sectors_wr = $delta_sectors_wr / ( $tstamp - $last_tstamp );
		$delta_sw_num_rd  = $delta_sw_num_rd /  ( $tstamp - $last_tstamp );
		$delta_sw_num_wr  = $delta_sw_num_wr /  ( $tstamp - $last_tstamp );
		$delta_sw_sectors_rd =
		  $delta_sw_sectors_rd / ( $tstamp - $last_tstamp );
		$delta_sw_sectors_wr =
		  $delta_sw_sectors_wr / ( $tstamp - $last_tstamp );
		$x = sprintf(
			"xid=$tstamp disk_rd=%.2f disk_wr=%.2f disk_sec_rd=%.2f "
			  . "disk_sec_wr=%.2f swap_rd=%.2f swap_wr=%.2f "
			  . "swap_sec_rd=%.2f swap_sec_wr=%.2f",
			$delta_num_rd,        $delta_num_wr,    $delta_sectors_rd,
			$delta_sectors_wr,    $delta_sw_num_rd, $delta_sw_num_wr,
			$delta_sw_sectors_rd, $delta_sw_sectors_wr
		);
		syslog( 'notice', $x );

		foreach $k ( keys(%curr_data) ) {
			$cp = $curr_data{$k};
			$pp = $prev_data{$k};
			for ( $kk = 0 ; $kk < scalar(@$cp) ; $kk++ ) {
				$pp->[$kk] = $cp->[$kk];
			}
		}
	}

	sub exit_diskstats {
		close(FPds);
	}
}

#
# for Scratch disk space
BEGIN {

	sub init_dfscratch {
		if ( not -e $scratch_dir ) {
			print "** Error: no scratch directory exists ($scratch_dir)\n";
		}
		if ( not -d $scratch_dir ) {
			print "** Error: scratch is not a directory ($scratch_dir)\n";
		}
	}

	sub next_dfscratch {
		my @list = ();
		my ($dffree);
		open( FP, "$df_cmd -k $scratch_dir 2>&1 |" );

		# skip first line (header)
		<FP>;
		$_ = <FP>;
		close(FP);
		@list = split( /\s+/, $_ );

		# change to bytes (from KB)
		$dffree = $list[3] * 1024;
		syslog( 'notice', "xid=$tstamp scr_free=$dffree" );
	}

	sub exit_dfscratch {
	}
}

#
# for Power usage
BEGIN {
	my $cmd1;
	my $wu_flag;

	sub init_wattage {
		my ($flag);

		$wu_flag = 0;
		if ( -e '/dev/ttyUSB0' ) {

			# assume any ttyUSB0 must be a WattsUp meter
			$cmd1    = "$wattsup_cmd -c 1 ttyUSB0 watts 2>&1 |";
			$wu_flag = 1;
		}
		else {
			$cmd1 = "$ipmitool_cmd -I open sdr list 2>&1 |";
		}

		# should do a test-run to make sure it works
		# and set cmd1='' if not
	}

	sub next_wattage {
		my ( $watts, $flag );
		$watts = -1.0;
		if ( $cmd1 ne '' ) {

			# trick from Lincoln Stein's book "Network programming with Perl"
			eval {
				local $SIG{ALRM} = sub { die '__timeout__' };
				alarm($timeout);
				open( PP, $cmd1 );
				while (<PP>) {
					if ( $_ =~ m/System Level\s+\|\s+(.*)/ ) {
						$watts = $1 + 0;
					}
					elsif ( $wu_flag and ( $_ =~ m/^(\d.*)/ ) ) {

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
		syslog( 'notice', "xid=$tstamp watts=$watts" );
	}

	sub exit_wattage {
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
		syslog( 'notice', "xid=$tstamp jobs=$count" );
	}

	sub exit_sge_shep {
		close(DPss);
	}
}

#
# for ping response times
BEGIN {

	sub init_ping {
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

				}
				elsif ( $data =~ m/ us/ ) {
					$msec = 0.001 * ( $data + 0 );
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
		syslog( 'notice', "xid=$tstamp ping=$msec" );
	}

	sub exit_ping {
	}
}
