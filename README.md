# memrec
Flight-recorder, Memory-recorder, Logging tools


Flight-recorder, Memory-recorder, Logging tools

These tools were designed for SIMPLE recordings of READILY AVAILBLE information in Linux,  
and the easiest way seemed to be a time-based profile of the various measurements.

The main driver scripts (dlogger, cronlogger, fltrec, stracedrv, ltracedrv) follow basically the same structure:

(0) optional:  module->prep( ... ) 
	some measurement modules can pre-populate lists, override defaults, etc.
	Note: all modules should define &prep, but you don't have to call it
(1) create the measurement modules/objects with mod->new()
	some measurement modules allow you to override defaults with module->new() args
(2) loop until program exists
  (a) collect new data:  module->getdata()
  (b) output data
  (c) sleep for N seconds
(3) repeat until target-program exits
(4) mostly for completeness:  module->delete()

There are some obvious caveats to what the tools can do -- keep in mind that the data is not perfect, but it is often quite useful:  

(*) Time-based profiles will probably miss short-lived events 
Most of the measurement modules rely on counters, so it is likely that you can get summary data or time-averaged data (averaged over whatever granularity you choose).

E.g. memory usage may spike in the middle of a sleep cycle; you may be able to see the effects of the spike in the high-water mark, but the recorded "memory-used" values may not show anything E.g. network usage may spike in the middle of the sleep cycle; you won't be able to tell if this was N bytes-per-sec over that time-window, or 100N bytes-per-second over a smaller window
	
(*) Linux only records some data at the machine level
If you are sharing the machine with other users or other programs, the data you record will include their contributions (which you probably can't pull out).

E.g. network usage is measuring all bytes in/out of the machine Easy solution is to find a "quiet" machine.

----------

The system-logging tool(s) came about since, once we had all the measurement modules, it was easy to re-use them for general system monitoring.  We've also done some integration with this into GridEngine "load-sensor" modules.

----------

Better looping structure is now used:

(A) fork/exec a new process to act as the "timer", with pipe between the two
(B) timer process loop:
   (i) sleep for N seconds
   (ii) send carriage-return to logger process
(C) logger process loop:
   (i) wait for carriage-return from timer process
   (ii) collect new data:  module->getdata()
   (iii) output data

Since timer does not spend time collecting data, it should provide better accuracy for the delta between collection time-stamps.  E.g. some network modules might wait for many seconds to try and collect data, those seconds will slowly cause the simpler loop (above) to drift.
 
