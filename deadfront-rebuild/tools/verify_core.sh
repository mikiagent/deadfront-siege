#!/usr/bin/env bash
# M0 core verification: clean headless import, then the typed domain test runner.
#
# Prints "M0 CORE VERIFY PASS" only when the import succeeded, no Godot script
# error was reported, the runner exited 0, and the runner printed its own PASS
# marker. Any other outcome exits non-zero without the marker.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "${HERE}/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
LOG_DIR="${PROJECT}/.verify-logs"
IMPORT_LOG="${LOG_DIR}/import.log"
TEST_LOG="${LOG_DIR}/tests.log"

if [[ ! -x "${GODOT}" ]]; then
  echo "[verify_core] Godot binary not found at ${GODOT}" >&2
  echo "[verify_core] set GODOT=/path/to/godot4 to override" >&2
  exit 2
fi

mkdir -p "${LOG_DIR}"

# Godot derives user:// from HOME ($HOME/Library/... on macOS). In sandboxed or
# CI runs HOME is not writable, which makes Godot crash while creating its data
# dir. Point it at a project-local, disposable home so the check is hermetic and
# needs no write access outside the project. Override with GODOT_HOME if wanted.
GODOT_HOME="${GODOT_HOME:-${LOG_DIR}/home}"
mkdir -p "${GODOT_HOME}"
export HOME="${GODOT_HOME}"

rm -rf "${PROJECT}/.godot"

echo "[verify_core] godot: $("${GODOT}" --version 2>&1 | head -1)"

echo "[verify_core] clean headless import"
"${GODOT}" --headless --path "${PROJECT}" --editor --quit >"${IMPORT_LOG}" 2>&1
import_status=$?
if (( import_status != 0 )); then
  echo "[verify_core] import FAILED (exit ${import_status}); log: ${IMPORT_LOG}" >&2
  tail -40 "${IMPORT_LOG}" >&2
  exit 1
fi
if grep -Eq "SCRIPT ERROR|Parse Error|ERROR: Failed to load script" "${IMPORT_LOG}"; then
  echo "[verify_core] import reported script errors; log: ${IMPORT_LOG}" >&2
  grep -E -A3 "SCRIPT ERROR|Parse Error|ERROR: Failed to load script" "${IMPORT_LOG}" | head -60 >&2
  exit 1
fi

echo "[verify_core] headless typed test runner"
"${GODOT}" --headless --path "${PROJECT}" --script res://tests/run_tests.gd >"${TEST_LOG}" 2>&1
test_status=$?
cat "${TEST_LOG}"

if (( test_status != 0 )); then
  echo "[verify_core] tests FAILED (exit ${test_status}); log: ${TEST_LOG}" >&2
  exit 1
fi
if grep -Eq "SCRIPT ERROR|Parse Error|Invalid call|Attempt to call" "${TEST_LOG}"; then
  echo "[verify_core] runner output contains script errors; log: ${TEST_LOG}" >&2
  exit 1
fi
if ! grep -Eq "^\[m0-core\] [0-9]+ checks, 0 failures" "${TEST_LOG}"; then
  echo "[verify_core] runner did not report zero failures; log: ${TEST_LOG}" >&2
  exit 1
fi
if ! grep -q "M0 CORE TESTS PASS" "${TEST_LOG}"; then
  echo "[verify_core] runner did not print its PASS marker; log: ${TEST_LOG}" >&2
  exit 1
fi

echo "[verify_core] all required core tests passed"
echo "M0 CORE VERIFY PASS"
