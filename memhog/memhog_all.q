#!/bin/tcsh
#
#$ -cwd
#$ -j y -o memhog.out
#$ -l mem_free=1G,arch=lx26-amd64

/home/csem/jbp1/rcc/sge_setlimit
limit

echo
echo __STARTING__

foreach x ( 800 900 1000 1010 1020 1021 1022 1023 1024 1025 )
  echo x is $x
  ./memhog0 -m ${x}M -s 1
  echo
end

echo __DONE__

