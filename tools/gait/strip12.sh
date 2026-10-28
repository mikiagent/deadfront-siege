#!/bin/bash
# strip12.sh <frames_dir> <out.png> : 12 evenly spaced frames, 6 per row
d=$1; out=$2; n=12; tot=$(ls $d/f*.png | wc -l | tr -d ' ')
tmp=$(mktemp -d)
for k in $(seq 0 $((n-1))); do f=$(( k*tot/n )); cp $(printf "$d/f%03d.png" $f) $tmp/s$(printf %02d $k).png; done
ffmpeg -loglevel error -y -i $tmp/s%02d.png -vf "scale=400:-1,tile=6x2" -frames:v 1 $out; rm -r $tmp
