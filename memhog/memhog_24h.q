#!/bin/tcsh
#
#$ -cwd
#$ -j y -o memhog_24h.out
#$ -l arch=lx26-amd64

./memhog64 -d2 24h

