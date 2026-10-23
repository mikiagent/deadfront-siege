#!/usr/bin/env bash
# verify_review.sh <key>: gate for a first-pass review job, run from the reviewed tree. The review must be
# docs/orchestration/reports/dsc-review-<key>.json + .md; every finding cites a file that exists and a line inside it.
K=$1; T=$(git rev-parse --show-toplevel); cd "$T" || exit 1
J=docs/orchestration/reports/dsc-review-$K.json
[ -s "$J" ] || { echo "VERIFY FAIL: $J missing"; exit 1; }
[ -s "docs/orchestration/reports/dsc-review-$K.md" ] || { echo "VERIFY FAIL: the .md summary is missing"; exit 1; }
python3 - "$J" <<'PY'
import json, os, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception as e:
    print("VERIFY FAIL: not JSON:", e); sys.exit(1)
bad = []
if d.get("verdict") not in ("pass", "fail"): bad.append("verdict must be pass or fail")
f = d.get("findings")
if not isinstance(f, list): bad.append("findings must be a list")
f = f or []
for i, x in enumerate(f):
    for k in ("severity", "file", "line", "problem", "evidence", "fix"):
        if k not in x: bad.append(f"finding {i} lacks {k}")
    if x.get("severity") not in ("blocker", "major", "minor"): bad.append(f"finding {i}: severity must be blocker/major/minor")
    p = str(x.get("file", ""))
    if not os.path.isfile(p): bad.append(f"finding {i}: file {p} does not exist")
    else:
        n = sum(1 for _ in open(p, errors="ignore"))
        try:
            ln = int(x.get("line", 0))
        except Exception:
            ln = -1
        if not (1 <= ln <= n): bad.append(f"finding {i}: line {x.get('line')} is not inside {p} ({n} lines)")
if d.get("verdict") == "fail" and not any(x.get("severity") in ("blocker", "major") for x in f):
    bad.append("a fail verdict needs at least one blocker or major")
if not d.get("checks_run"): bad.append("checks_run must list the tests/labs you ran and their result lines")
for b in bad: print("VERIFY FAIL:", b)
print(f"findings={len(f)} verdict={d.get('verdict')}")
sys.exit(1 if bad else 0)
PY
