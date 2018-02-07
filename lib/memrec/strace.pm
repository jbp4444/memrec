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
# RCSID $Id: strace.pm 421 2012-05-21 13:58:30Z jbp $

package strace;
require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw( &new &prep );

my %funcs;
my %all_funcs = (
	'accept'                 => 1,
	'access'                 => 1,
	'acct'                   => 1,
	'add_key'                => 1,
	'adjtimex'               => 1,
	'afs_syscall'            => 1,
	'alarm'                  => 1,
	'alloc_hugepages'        => 1,
	'arch_prctl'             => 1,
	'bdflush'                => 1,
	'bind'                   => 1,
	'break'                  => 1,
	'brk'                    => 1,
	'cacheflush'             => 1,
	'chdir'                  => 1,
	'chmod'                  => 1,
	'chown'                  => 1,
	'chroot'                 => 1,
	'clock_getres'           => 1,
	'clock_gettime'          => 1,
	'clock_nanosleep'        => 1,
	'clock_settime'          => 1,
	'clone2'                 => 1,
	'clone'                  => 1,
	'close'                  => 1,
	'connect'                => 1,
	'creat'                  => 1,
	'create_module'          => 1,
	'delete_module'          => 1,
	'dup2'                   => 1,
	'dup'                    => 1,
	'epoll_create'           => 1,
	'epoll_ctl'              => 1,
	'epoll_wait'             => 1,
	'execve'                 => 1,
	'_exit'                  => 1,
	'exit'                   => 1,
	'_Exit'                  => 1,
	'exit_group'             => 1,
	'faccessat'              => 1,
	'fadvise'                => 1,
	'fadvise64'              => 1,
	'fadvise64_64'           => 1,
	'fattch'                 => 1,
	'fchdir'                 => 1,
	'fchmod'                 => 1,
	'fchmodat'               => 1,
	'fchown'                 => 1,
	'fchownat'               => 1,
	'fcntl'                  => 1,
	'fdatasync'              => 1,
	'fdetach'                => 1,
	'flock'                  => 1,
	'fork'                   => 1,
	'free_hugepages'         => 1,
	'fstat'                  => 1,
	'fstatat'                => 1,
	'fstatfs'                => 1,
	'fstatvfs'               => 1,
	'fsync'                  => 1,
	'ftruncate'              => 1,
	'futex'                  => 1,
	'futimesat'              => 1,
	'getcontext'             => 1,
	'getcwd'                 => 1,
	'getdents'               => 1,
	'getdomainname'          => 1,
	'getdtablesize'          => 1,
	'getegid'                => 1,
	'geteuid'                => 1,
	'getgid'                 => 1,
	'getgroups'              => 1,
	'gethostid'              => 1,
	'gethostname'            => 1,
	'getitimer'              => 1,
	'get_kernel_syms'        => 1,
	'get_mempolicy'          => 1,
	'getmsg'                 => 1,
	'getpagesize'            => 1,
	'getpeername'            => 1,
	'getpgid'                => 1,
	'getpgrp'                => 1,
	'getpid'                 => 1,
	'getpmsg'                => 1,
	'getppid'                => 1,
	'getpriority'            => 1,
	'getresgid'              => 1,
	'getresuid'              => 1,
	'getrlimit'              => 1,
	'get_robust_list'        => 1,
	'getrusage'              => 1,
	'getsid'                 => 1,
	'getsockname'            => 1,
	'getsockopt'             => 1,
	'get_thread_area'        => 1,
	'gettid'                 => 1,
	'gettimeofday'           => 1,
	'getuid'                 => 1,
	'getunwind'              => 1,
	'gtty'                   => 1,
	'idle'                   => 1,
	'inb'                    => 1,
	'inb_p'                  => 1,
	'init_module'            => 1,
	'inl'                    => 1,
	'inl_p'                  => 1,
	'inotify_add_watch'      => 1,
	'inotify_init'           => 1,
	'inotify_rm_watch'       => 1,
	'insb'                   => 1,
	'insl'                   => 1,
	'insw'                   => 1,
	'intro'                  => 1,
	'inw'                    => 1,
	'inw_p'                  => 1,
	'io_cancel'              => 1,
	'ioctl'                  => 1,
	'ioctl_list'             => 1,
	'io_destroy'             => 1,
	'io_getevents'           => 1,
	'ioperm'                 => 1,
	'iopl'                   => 1,
	'ioprio_get'             => 1,
	'ioprio_set'             => 1,
	'io_setup'               => 1,
	'io_submit'              => 1,
	'ipc'                    => 1,
	'isastream'              => 1,
	'kexec_load'             => 1,
	'keyctl'                 => 1,
	'kill'                   => 1,
	'killpg'                 => 1,
	'lchown'                 => 1,
	'link'                   => 1,
	'linkat'                 => 1,
	'listen'                 => 1,
	'_llseek'                => 1,
	'llseek'                 => 1,
	'lock'                   => 1,
	'lookup_dcookie'         => 1,
	'lseek'                  => 1,
	'lstat'                  => 1,
	'madvise'                => 1,
	'mincore'                => 1,
	'mkdir'                  => 1,
	'mkdirat'                => 1,
	'mknod'                  => 1,
	'mknodat'                => 1,
	'mlock'                  => 1,
	'mlockall'               => 1,
	'mmap2'                  => 1,
	'mmap'                   => 1,
	'modify_ldt'             => 1,
	'mount'                  => 1,
	'move_pages'             => 1,
	'mprotect'               => 1,
	'mpx'                    => 1,
	'mq_getsetattr'          => 1,
	'mremap'                 => 1,
	'msgctl'                 => 1,
	'msgget'                 => 1,
	'msgop'                  => 1,
	'msgrcv'                 => 1,
	'msgsnd'                 => 1,
	'msync'                  => 1,
	'multiplexer'            => 1,
	'munlock'                => 1,
	'munlockall'             => 1,
	'munmap'                 => 1,
	'nanosleep'              => 1,
	'_newselect'             => 1,
	'nfsservctl'             => 1,
	'nice'                   => 1,
	'obsolete'               => 1,
	'oldfstat'               => 1,
	'oldlstat'               => 1,
	'oldolduname'            => 1,
	'oldstat'                => 1,
	'olduname'               => 1,
	'open'                   => 1,
	'openat'                 => 1,
	'outb'                   => 1,
	'outb_p'                 => 1,
	'outl'                   => 1,
	'outl_p'                 => 1,
	'outsb'                  => 1,
	'outsl'                  => 1,
	'outsw'                  => 1,
	'outw'                   => 1,
	'outw_p'                 => 1,
	'path_resolution'        => 1,
	'pause'                  => 1,
	'perfmonctl'             => 1,
	'personality'            => 1,
	'pipe'                   => 1,
	'pivot_root'             => 1,
	'poll'                   => 1,
	'posix_fadvise'          => 1,
	'ppoll'                  => 1,
	'prctl'                  => 1,
	'pread'                  => 1,
	'prof'                   => 1,
	'pselect'                => 1,
	'ptrace'                 => 1,
	'putmsg'                 => 1,
	'putpmsg'                => 1,
	'pwrite'                 => 1,
	'query_module'           => 1,
	'quotactl'               => 1,
	'read'                   => 1,
	'readahead'              => 1,
	'readdir'                => 1,
	'readlink'               => 1,
	'readlinkat'             => 1,
	'readv'                  => 1,
	'reboot'                 => 1,
	'recv'                   => 1,
	'recvfrom'               => 1,
	'recvmsg'                => 1,
	'remap_file_pages'       => 1,
	'rename'                 => 1,
	'renameat'               => 1,
	'request_key'            => 1,
	'restart_syscall'        => 1,
	'rmdir'                  => 1,
	'rtas'                   => 1,
	'rt_sigaction'           => 1,
	'rt_sigpending'          => 1,
	'rt_sigprocmask'         => 1,
	'rt_sigqueueinfo'        => 1,
	'rt_sigreturn'           => 1,
	'rt_sigsuspend'          => 1,
	'rt_sigtimedwait'        => 1,
	'sbrk'                   => 1,
	'sched_getaffinity'      => 1,
	'sched_getparam'         => 1,
	'sched_get_priority_max' => 1,
	'sched_get_priority_min' => 1,
	'sched_getscheduler'     => 1,
	'sched_rr_get_interval'  => 1,
	'sched_setaffinity'      => 1,
	'sched_setparam'         => 1,
	'sched_setscheduler'     => 1,
	'sched_yield'            => 1,
	'security'               => 1,
	'select'                 => 1,
	'select_tut'             => 1,
	'semctl'                 => 1,
	'semget'                 => 1,
	'semop'                  => 1,
	'semtimedop'             => 1,
	'send'                   => 1,
	'sendfile'               => 1,
	'sendmsg'                => 1,
	'sendto'                 => 1,
	'setcontext'             => 1,
	'setdomainname'          => 1,
	'setegid'                => 1,
	'seteuid'                => 1,
	'setfsgid'               => 1,
	'setfsuid'               => 1,
	'setgid'                 => 1,
	'setgroups'              => 1,
	'sethostid'              => 1,
	'sethostname'            => 1,
	'setitimer'              => 1,
	'setpgid'                => 1,
	'setpgrp'                => 1,
	'setpriority'            => 1,
	'setregid'               => 1,
	'setresgid'              => 1,
	'setresuid'              => 1,
	'setreuid'               => 1,
	'setrlimit'              => 1,
	'set_robust_list'        => 1,
	'setsid'                 => 1,
	'setsockopt'             => 1,
	'set_thread_area'        => 1,
	'set_tid_address'        => 1,
	'settimeofday'           => 1,
	'setuid'                 => 1,
	'setup'                  => 1,
	'sgetmask'               => 1,
	'shmat'                  => 1,
	'shmctl'                 => 1,
	'shmdt'                  => 1,
	'shmget'                 => 1,
	'shmop'                  => 1,
	'shutdown'               => 1,
	'sigaction'              => 1,
	'sigaltstack'            => 1,
	'signal'                 => 1,
	'sigpending'             => 1,
	'sigprocmask'            => 1,
	'sigqueue'               => 1,
	'sigreturn'              => 1,
	'sigsuspend'             => 1,
	'sigtimedwait'           => 1,
	'sigwaitinfo'            => 1,
	'socket'                 => 1,
	'socketcall'             => 1,
	'socketpair'             => 1,
	'splice'                 => 1,
	'spu_create'             => 1,
	'spufs'                  => 1,
	'spu_run'                => 1,
	'ssetmask'               => 1,
	'stat'                   => 1,
	'statfs'                 => 1,
	'statfs64'               => 1,
	'statvfs'                => 1,
	'stime'                  => 1,
	'stty'                   => 1,
	'swapcontext'            => 1,
	'swapoff'                => 1,
	'swapon'                 => 1,
	'symlink'                => 1,
	'symlinkat'              => 1,
	'sync'                   => 1,
	'sync_file_range'        => 1,
	'_syscall'               => 1,
	'syscall'                => 1,
	'syscalls'               => 1,
	'_sysctl'                => 1,
	'sysctl'                 => 1,
	'sysfs'                  => 1,
	'sysinfo'                => 1,
	'syslog'                 => 1,
	'tee'                    => 1,
	'tgkill'                 => 1,
	'time'                   => 1,
	'timer_create'           => 1,
	'timer_delete'           => 1,
	'timer_getoverrun'       => 1,
	'timer_gettime'          => 1,
	'timer_settime'          => 1,
	'times'                  => 1,
	'tkill'                  => 1,
	'truncate'               => 1,
	'tux'                    => 1,
	'umask'                  => 1,
	'umount2'                => 1,
	'umount'                 => 1,
	'uname'                  => 1,
	'undocumented'           => 1,
	'unimplemented'          => 1,
	'unlink'                 => 1,
	'unlinkat'               => 1,
	'unshare'                => 1,
	'uselib'                 => 1,
	'ustat'                  => 1,
	'utime'                  => 1,
	'utimes'                 => 1,
	'vfork'                  => 1,
	'vhangup'                => 1,
	'vm86'                   => 1,
	'vm86old'                => 1,
	'vmsplice'               => 1,
	'vserver'                => 1,
	'wait'                   => 1,
	'wait3'                  => 1,
	'wait4'                  => 1,
	'waitid'                 => 1,
	'waitpid'                => 1,
	'write'                  => 1,
	'writev'                 => 1,
);
my $prep_done = 0;

sub prep {
	my $class = shift;
	my $prog = shift( @_ );
	my $flist = shift(@_);
	my ($x,$y,$fcn,$pp);
	
	# populate %all_funcs from nm output
	if( $prog ne '' ) {
		# nm only output external syms, not sys-calls
		# TODO - can we find what syscalls are relevant to this prog?
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
	my $pid   = shift(@_);
	my $self  = {};
	my ($fp);

	if( $prep_done == 0 ) {
		%funcs = %all_funcs;
	}

	# '-f' is to catch forks
	# '-s 0' to NOT print strings (still prints filenames)
	open( $fp, "/usr/bin/strace -f -s 0 -p $pid 2>&1 |" )
	  or die "cannot open strace to pid [$pid]\n";

	$self->{'pid'} = $pid;
	$self->{'fp'}  = $fp;

	bless( $self, $class );
	return $self;
}

sub getdata {
	my $self = shift;
	my $dref = shift(@_);
	my $pid  = $self->{'pid'};
	my $fp   = $self->{'fp'};
	my ( $x, $y, $flag, $bytes, $text, $fcn );
	my %data    = ();
	my @fld     = ();
	my $rfd     = '';
	my $timeout = 0.1;    # in sec

	foreach $x ( keys(%funcs) ) {
		$data{$x} = 0;
	}

	$flag = 1;
	$rfd  = '';
	vec( $rfd, fileno($fp), 1 ) = 1;
	$flag = 0 unless select( $rfd, undef, undef, $timeout ) > 0;

	#
	# process all new data items
	$text = '';
	while ($flag) {
		$bytes = sysread( $fp, $x, 1024 );
		if ( $bytes > 0 ) {
			$text .= $x;
		} else {
			$flag = 0;
			last;
		}

		$rfd = '';
		vec( $rfd, fileno($fp), 1 ) = 1;
		$flag = 0 unless select( $rfd, undef, undef, $timeout ) > 0;
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

	return (0);
}

sub delete {
	my $self = shift;

	# we should probably check that strace has/hasn't already exitted

	close( $self->{'fp'} );
}

1;
