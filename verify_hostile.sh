#!/bin/zsh
# Read-only spec gate for the dsc hostile-args task. Exit 0 only when every check holds.
cd "$(dirname "$0")"
SP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
G=/Applications/Godot_mono.app/Contents/MacOS/Godot
BASE=96b41ed3
F=game/tests/srvdom_checks.gd
rc=0
fail() { echo "FAIL $*"; rc=1; }
run_suite() { $SP/gslot.sh perl -e 'alarm 300; exec @ARGV' $G --headless --path game -s res://tests/t_srvdom.gd > "$1" 2>&1; }

# 1. Scope: only the test file (and TASK.md) differ from the base commit; no new files under game/.
bad=$(git diff --name-only $BASE | grep -v -e "^$F\$" -e '^TASK.md$')
[[ -z $bad ]] || fail "edits outside $F: $bad"
new=$(git ls-files --others --exclude-standard game/scripts game/tests game/data)
[[ -z $new ]] || fail "new files: $new"

# 2. The table is literal: one row per line, a literal expected code, never server_error.
[[ $(grep -c '^const HOSTILE' $F) -eq 1 ]] || fail "no single 'const HOSTILE'"
rows=$(grep -cE '^[[:space:]]*\["(act|char)\.[a-z]+", \{.*\}, "[a-z_]+"\],?[[:space:]]*(#.*)?$' $F)
(( rows >= 60 )) || fail "HOSTILE has $rows one-line rows, need >= 60"
grep -E '^[[:space:]]*\["(act|char)\.[a-z]+", \{.*\}, "server_error"\]' $F >/dev/null && fail "a row expects server_error"
for op in act.gather act.loot act.craft act.place act.equip act.eat act.tame act.capture act.attack act.deposit char.import char.create char.move char.wallet char.receive char.settled; do
  n=$(grep -cE "^[[:space:]]*\[\"${op//./\\.}\", \{" $F)
  (( n >= 3 )) || fail "$op has $n rows, need >= 3"
done
[[ $(grep -c '_hostile_arg_checks()' $F) -ge 2 ]] || fail "_hostile_arg_checks() not defined and called"

# 3. The suite passes with the evidence line and every earlier check intact.
L=$(mktemp); run_suite $L; c=$?
[[ $c -eq 0 ]] && grep -q '^\[t_srvdom\] PASS' $L || fail "t_srvdom did not PASS (rc=$c): $(grep -E 'FAIL|SCRIPT ERROR|Parse Error' $L | head -5)"
grep -q 'SCRIPT ERROR' $L && fail "SCRIPT ERROR in the run: $(grep -m3 'SCRIPT ERROR' $L)"
h=$(grep -m1 '^\[srvdom\] hostile ' $L)
echo "evidence: $h"
[[ $h =~ 'rows=([0-9]+) ops_covered=([0-9]+) matched=([0-9]+) script_errors=([0-9]+) unchanged=(true|false) allowlist_ops=([0-9]+)' ]] || fail "hostile evidence line missing or malformed"
if [[ -n $match ]]; then
  r=$match[1]; (( r >= 60 && r == rows )) || fail "rows=$r (table lines $rows)"
  (( match[2] == 16 )) || fail "ops_covered=$match[2], need 16"
  (( match[3] == r )) || fail "matched=$match[3] of $r"
  (( match[4] == 0 )) || fail "script_errors=$match[4]"
  [[ $match[5] == true ]] || fail "unchanged=$match[5]"
  (( match[6] == 17 )) || fail "allowlist_ops=$match[6], need 17"
fi
for pre in 'gather uid=' 'craft twine' 'tame pet=' 'offline import' 'rid invalid' 'rid repeat' 'move budget' 'receive item=' 'world writes' 'capture throws=' 'hardening flags=' 'fuzz ops=10000' 'replay lines=.*byte_identical=true' 'disk seq='; do
  grep -qE "^\[srvdom\] $pre" $L || fail "earlier evidence line '[srvdom] $pre' is gone"
done

# 4. Mutation: a wrong expected code in the first row must make the suite FAIL (the check really compares).
cp $F $SP/verify_hostile_backup.gd
restore() { cp $SP/verify_hostile_backup.gd $F; }
trap restore EXIT INT TERM
first=$(grep -nE '^[[:space:]]*\["(act|char)\.[a-z]+", \{.*\}, "[a-z_]+"\]' $F | head -1 | cut -d: -f1)
if [[ -n $first ]]; then
  sed -i '' -E "${first}s/, \"[a-z_]+\"\](,?)/, \"zz_mutant\"]\1/" $F
  run_suite $L
  grep -q '^\[t_srvdom\] FAIL' $L || fail "a row expecting zz_mutant did not fail the suite"
fi
restore
cmp -s $F $SP/verify_hostile_backup.gd || fail "could not restore $F after the mutation run"
rm -f $L
(( rc == 0 )) && echo "VERIFY PASS"
exit $rc
