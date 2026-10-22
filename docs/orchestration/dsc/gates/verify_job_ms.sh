#!/usr/bin/env bash
# verify_job_ms.sh <key> <milestone n>: milestone gate. If job_<key>.conf defines MS_CMD_<n>, that command is the gate for
# milestone n (run from the work tree). Otherwise milestones before MS_STAGE2 run stage 1 and later ones stage 2.
D=$(cd "$(dirname "$0")" && pwd)
. "$D/job_$1.conf" || exit 1
n=${2:-1}
eval "c=\${MS_CMD_$n:-}"
if [ -n "$c" ]; then
  cd "$(git rev-parse --show-toplevel)" || exit 1
  bash -c "$c" && { echo "MILESTONE $n GATE PASS"; exit 0; }
  echo "MILESTONE $n GATE FAIL: $c"; exit 1
fi
s=1; [ "$n" -ge "${MS_STAGE2:-3}" ] && s=2
exec bash "$D/verify_job.sh" "$1" "$s"
