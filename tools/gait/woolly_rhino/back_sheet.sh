#!/bin/bash
# sheet.sh <prefix> <out.jpg>: 3x2 grid of the six back views
p=$1; ffmpeg -loglevel error -y -i ${p}_top.png -i ${p}_rear_high.png -i ${p}_rq_left.png -i ${p}_rq_right.png -i ${p}_side_left_high.png -i ${p}_side_right_high.png \
 -filter_complex "[0][1][2]hstack=3[a];[3][4][5]hstack=3[b];[a][b]vstack,scale=1350:-1" -q:v 3 $2
