## Flight-recorder, Memory-recorder, Logging tools

These tools were designed for SIMPLE recordings of READILY AVAILBLE information in Linux, and the easiest way seemed to be a time-based profile of the various measurements.  
They primarily wait N seconds, take a set of measurements, write them out to a file or system log, then repeat.  

* `bin/memrec.pl /path/to/my_code --with-args`
  * runs `my_code` while recording standard data about the system (cpu, memory, etc.) and sending it to a file
* `sbin/dlogger.pl`
  * runs in the background (as a daemon process), records stardard data about the system and outputs it to a system log
* `sbin/cronlogger.pl`
  * as above, but if you prefer to run through `cron` rather than as a daemon
  * note that this implies more overhead since each `cron` run will have to re-initialize everything
* `sbin/qloadsensor.pl`
  * a load-sensor for the Sun Grid Engine batch scheduler (could potentially be adapted for other schedulers?)
* `sbin/duologger.pl`
  * an experimental daemon to run some modules more frequently than others; e.g. to monitor network usage at 1 min increments, but output min/max/etc. stats every 10 min

There are modules in `./lib` for CPU-type info, disk-full, disk-IO, GPU-type info, GPU load, Sun Grid Engine (and Condor) info, network config, network-IO, network ping checks, memory info, load average, mount-check (is a mount-point available), NFS-client status, operating system info, power usage info (through IPMI or WattsUp meters), SGE status, Intel TurboBoost info (from their turbostat tool), and a few more.

The system is configured with a (Perl-syntax) config file -- see `./etc` for more examples:
```
our $heartbeat   = 60*10;  # num seconds for inner loop (every 10 min)
our $loglocal    = 'local4';
our $output      = 'syslog';
our @objs;

# what modules do you need?
use cpuinfo;
use gpuinfo;
use ifconfig;
use procstat;
use netinfo;
use diskstats;

# modules to poll
push( @objs, cpuinfo->new() );
push( @objs, gpuinfo->new() );
push( @objs, ifconfig->new() );
push( @objs, procstat->new() );
push( @objs, netinfo->new() );
push( @objs, diskstats->new() );

1;
```

### Main Driver Scripts

The main driver scripts (dlogger, cronlogger, memrec) follow basically the same structure:

1. optional:  module->prep( ... ) 
	some measurement modules can pre-populate lists, override defaults, etc.
	Note: all modules should define &prep, but you don't have to call it
2. create the measurement modules/objects with mod->new()
	some measurement modules allow you to override defaults with module->new() args
3. loop until program exists
  1. collect new data:  module->getdata()
  2. output data
  3. sleep for N seconds
4. repeat until target-program exits
5. mostly for completeness:  module->delete()

The "sleep for N seconds" part actually uses a second (forked) process to keep better time:

1. fork/exec a new process to act as the "timer", with pipe between the two
2. the timer process loop:
   1. sleep for N seconds
   2. send carriage-return to logger process
3. the logger process loop:
   1. wait for carriage-return from timer process
   2. collect new data:  module->getdata()
   3. output data

Since forked timer does not spend time collecting data, it should provide better accuracy for the delta between collection time-stamps.  
E.g. some network modules might wait for many seconds to try and collect data, those seconds will slowly cause a simpler `sleep`-based loop to drift.

### Notes & Caveats

There are some obvious caveats to what the tools can do -- keep in mind that the data is not perfect, but it is often quite useful:  

#### Time-based profiles will probably miss short-lived events
Most of the measurement modules rely on counters, so it is likely that you can get summary data or time-averaged data (averaged over whatever granularity you choose).  E.g. memory usage may spike in the middle of a sleep cycle; you may be able to see the effects of the spike in the high-water mark, but the recorded "memory-used" values may not show anything; with network IO, you won't be able to tell if the reading was N bytes-per-sec over the full time-window, or 100N bytes-per-second over a much smaller window.

#### Linux only records some data at the machine level
If you are sharing the machine with other users or other programs, the data you record will include their contributions (which you probably can't pull out).  E.g. network usage is measuring all bytes in/out of the machine Easy solution is to find a "quiet" machine.

#### System logs
The use of system logs allows you to use "regular" syslog tooling to redirect them to different files (through `/etc/syslog.conf`), to rotate the files (`/etc/logrotate.conf`), etc.

#### Extra Tools
`memhog` and `iohog` and `calcpi` can be used for testing -- they will try to consume memory, IO ops, or cpu ops, respectively.

* `calcpi -t 8` will run 8 calc-pi threads (which should max out 8 cpus)
* `memhog.pl -m 100G` will run 1 process which will attempt to allocate 100GB of memory
* `iohog -n 1000 -r 1K -f dummyfile` will write 1000 records (of 1KB each) to a dummy file
* most of the tools will take a delay parameter, and allow for a "spike" (add more load after a delay)

#### Dual-Level Logging
The `duologger.pl` script runs N "inner-iterations" for every "outer" sampling run -- with 2 different sets of modules for the inner- and outer-loops. This allows you to run, say, the
``netinfo10.pm`` module every minute, then aggregate statistics every 10 minutes.  The goal is that you would be able to see 1-min long network usage spikes that would otherwise be 
hidden at a 10-min granularity.
```
our $heartbeat   = 60;  # num seconds for inner loop
our $inner2outer = 10;  # num inner loops per outer

# what modules do you need?
use ping;
use netinfo10;

# to config a module, use its prep(key,val) function
ping->prep( 'ping_ip', '10.184.3.10');

# modules to poll more often (inner loop)
push( @objs_in, netinfo10->new() );

# modules to poll less often (outer loop)
push( @objs_out, ping->new() );

1;
```

#### strace and ltrace modules
There are some not-quite-production-grade modules for `strace` and `ltrace` monitoring.  These assume they're being run with `bin/memrec.pl` and thus they can attach to a child-process-PID.
The idea is that they can watch for system- and function-calls that the child is making and report on them as just-another-stat.  See `test/stracedrv.pl` and `test/ltracedrv.pl` for examples.


## External and Vendor Tools
* The `src/tstat/turbostat.c` code comes from Intel Corporation -- https://intel.com
  * The version in this repos is for "historical" purposes only; it shows a 2010 copyright notice; surely there's a newer/better version available today!
* The `src/wattsup/wattsup.c` code comes from Patrick Mochel
  * The version in this repos is (C) 2005, so there is likely a newer/better version!
  * The WattsUp Pro meter included a USB connector (the non-Pro model did not); the code pulls the data over USB
* The `src/ipmitool-1.8.9` code is from a number of authors
  * Again, the version in this repos is for "historical" purposes; it shows a 2005 copyright; surely there's a newer/better version available today!
  * Dell provides power-usage data through IPMI on many of their server products; other vendors likely do the same (but that hasn't been tested)
