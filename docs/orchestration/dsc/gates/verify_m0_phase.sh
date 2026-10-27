#!/usr/bin/env bash
# The superplan runs every verification gate once before a worker starts.
# M0 deliberately creates the isolated project and its phase-local verifier, so
# this stable wrapper gives the baseline an expected ordinary failure instead
# of a missing-command crash. Once the phase artifact exists, it delegates to
# the real worker-authored test gate.
set -u

if [[ $# -ne 1 ]]; then
  echo "usage: $0 {core|persistence|shell|audit}" >&2
  exit 64
fi

case "$1" in
  core)
    target="deadfront-rebuild/tools/verify_core.sh"
    ;;
  persistence)
    target="deadfront-rebuild/tools/verify_persistence.sh"
    ;;
  shell|audit)
    target="deadfront-rebuild/tools/verify_m0.sh"
    ;;
  *)
    echo "unknown M0 phase: $1" >&2
    exit 64
    ;;
esac

if [[ ! -f "$target" ]]; then
  echo "[m0-phase-gate] waiting for phase verifier: $target" >&2
  exit 1
fi

exec bash "$target"
