# config file for qloadsensor
# (perl syntax)

use df;
use cpuinfo;
use linpack;
use gpuinfo;
use ipmiinfo;

# probably don't need serial-nums in qloadsensor
#ipmiinfo->prep( 'show_serial', 1 );

push( @objs, df->new( 'scr_free', '/scratch' ) );
push( @objs, cpuinfo->new() );
push( @objs, linpack->new() );
push( @objs, gpuinfo->new() );
push( @objs, ipmiinfo->new() );

1;
