#!/bin/bash
# strip.sh <frames_dir> <out.png> <count> : pick <count> evenly spaced frames, tile 4 per row
d=$1; out=$2; n=${3:-8}; tot=$(ls $d/f*.png | wc -l | tr -d ' ')
tmp=$(mktemp -d); i=0
for k in $(seq 0 $((n-1))); do f=$(( k*tot/n )); cp $(printf "$d/f%03d.png" $f) $tmp/s$(printf %02d $k).png; done
ffmpeg -loglevel error -y -i $tmp/s%02d.png -vf "scale=480:-1,tile=4x$(( (n+3)/4 ))" -frames:v 1 $out
rm -r $tmp
