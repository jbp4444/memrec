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

The system is configured with a (Perl-syntax) config file:
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

Since forked timer does not spend time collecting data, it should provide better accuracy for the delta between collection time-stamps.  E.g. some network modules might wait for many seconds to try and collect data, those seconds will slowly cause a simpler `sleep`-based loop to drift.

### Notes & Caveats

There are some obvious caveats to what the tools can do -- keep in mind that the data is not perfect, but it is often quite useful:  

Time-based profiles will probably miss short-lived events 
: Most of the measurement modules rely on counters, so it is likely that you can get summary data or time-averaged data (averaged over whatever granularity you choose).
: E.g. memory usage may spike in the middle of a sleep cycle; you may be able to see the effects of the spike in the high-water mark, but the recorded "memory-used" values may not show anything E.g. network usage may spike in the middle of the sleep cycle; you won't be able to tell if this was N bytes-per-sec over that time-window, or 100N bytes-per-second over a smaller window

Linux only records some data at the machine level
: If you are sharing the machine with other users or other programs, the data you record will include their contributions (which you probably can't pull out).
: E.g. network usage is measuring all bytes in/out of the machine Easy solution is to find a "quiet" machine.

System logs
: The use of system logs allows you to use "regular" syslog tooling to redirect them to different files, to rotate the files, etc.

