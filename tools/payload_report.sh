#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf 'Tracked payload by top-level path\n'
git -C "$ROOT" ls-tree -r -l HEAD | awk '{size=$4; path=$5; split(path,parts,"/"); sum[parts[1]]+=size} END {for (p in sum) printf "%12d  %s\n",sum[p],p}' | sort -nr
printf '\nLargest tracked blobs\n'
git -C "$ROOT" ls-tree -r -l HEAD | sort -k4nr | head -30
