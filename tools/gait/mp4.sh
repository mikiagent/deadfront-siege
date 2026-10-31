#!/bin/bash
# mp4.sh <old_frames> <new_frames> <out.mp4> <seconds> : old on top, new below, looped
ffmpeg -loglevel error -y -stream_loop -1 -framerate 24 -i $1/f%03d.png -stream_loop -1 -framerate 24 -i $2/f%03d.png \
  -filter_complex "[0]scale=640:-2[a];[1]scale=640:-2[b];[a][b]vstack,format=yuv420p" -t $4 -c:v libx264 -crf 20 $3
