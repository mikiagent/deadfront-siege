#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="$($ROOT/tools/find_godot.sh)"
"$G" --headless --path "$ROOT/game" --import
"$G" --headless --path "$ROOT/game" --script res://tests/run_all.gd
