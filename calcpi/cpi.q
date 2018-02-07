Executable     = /bdscratch/jbp1/memrec/calcpi/calcpi
Arguments      = -d 1400 -n 1e8
Output         = cpi.out
Log            = cpi.log
Getenv         = True
Requirements   = machine == "bdgpu-n02.oit.duke.edu"
Notification   = error
Queue


