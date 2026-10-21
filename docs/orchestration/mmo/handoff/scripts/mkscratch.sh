#!/usr/bin/env bash
# mkscratch.sh <name> <ref> [patch ...]: throwaway DETACHED tree for reviewers/sync checks.
# Clones the integration import cache, isolates user://, applies the given patches (paths relative to the
# tree, e.g. docs/orchestration/reports/claude-mmo-w2-data-hooks.patch), imports once, prints the path.
# Reusing <name> replaces the old tree (keeps disk use to one tree per name).
set -euo pipefail
name=$1; ref=$2; shift 2
R=/Users/milankinzy/Documents/deadfront-siege
OSP=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad
W=/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/trees/$name
mkdir -p "$(dirname "$W")"
# Disk guard: agents make many uniquely named trees (1.6 GB each). Keep at most 12; drop the oldest ones that no
# process uses and nothing touched for 30 minutes, and refuse below 15 GB free.
T=$(dirname "$W")
n=$(ls -1d "$T"/*/ 2>/dev/null | wc -l | tr -d " ")
if [ "$n" -ge 12 ]; then
  for d in $(ls -1dtr "$T"/*/ 2>/dev/null); do
    d=${d%/}; [ "$d" = "$W" ] && continue
    [ "$(lsof +d "$d" 2>/dev/null | wc -l | tr -d " ")" = "0" ] || continue
    [ -z "$(find "$d" -maxdepth 3 -newermt "-30 minutes" -not -path "*/.godot/*" 2>/dev/null | head -1)" ] || continue
    git -C "$R" worktree remove --force "$d" 2>/dev/null || rm -rf "$d"; n=$((n-1)); [ "$n" -lt 10 ] && break
  done
  git -C "$R" worktree prune
fi
free_gb=$(df -g "$T" | awk 'NR==2{print $4}')
if [ "${free_gb:-0}" -lt 15 ]; then echo "mkscratch: only ${free_gb} GB free; reuse an existing tree name instead of making a new one" >&2; exit 4; fi
if [ -e "$W" ]; then git -C "$R" worktree remove --force "$W" 2>/dev/null || rm -rf "$W"; git -C "$R" worktree prune; fi
git -C "$R" worktree add -q --detach "$W" "$ref"
cp -Rc "$R/.claude/worktrees/mmo-overhaul/game/.godot" "$W/game/.godot"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="deadfront-scratch-%s"\n' "$name" > "$W/game/override.cfg"
cd "$W"
for p in "$@"; do
  git apply --3way "$p" || { echo "mkscratch: patch did not apply: $p" >&2; exit 3; }
done
"$OSP/gslot.sh" perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > "$W/.import.log" 2>&1 || echo "mkscratch: import exit $? (see $W/.import.log)" >&2
echo "$W"
