#!/bin/tcsh
#
#$ -cwd
#$ -j y -o memhog.out
#$ -l mem_free=1G,arch=lx26-amd64
#$ -l highprio

./memhog64 -d0 10 -d1 10 -d2 10

