#!/usr/bin/env bash
# mkwt.sh <key> [base]: package worktree on branch claude/mmo-<key> with cloned import cache and isolated user dir.
set -euo pipefail
key=$1; base=${2:-claude/mmo-overhaul}
R=/Users/milankinzy/Documents/deadfront-siege
W=$R/.claude/worktrees/mmo-$key
cd $R
git worktree add -q "$W" -b "claude/mmo-$key" "$base"
cp -Rc "$R/.claude/worktrees/mmo-overhaul/game/.godot" "$W/game/.godot"
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="deadfront-mmo-%s"\n' "$key" > "$W/game/override.cfg"
# The base cache can lag merged assets (merges are imported in mmo-int, not here): import once so labs
# in the new tree do not log missing-resource ERRORs that look like code bugs.
( cd "$W" && /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /dev/null 2>&1 ) || echo "mkwt: import failed in $W" >&2
echo "$W"
