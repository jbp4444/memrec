#!/bin/csh

echo x${argv}x
foreach x ( $argv )
  echo $x
  ./calcpi 1e9 ; ./calcpi 1e9 ; ./calcpi 1e9 ; ./calcpi 1e9 &
end



