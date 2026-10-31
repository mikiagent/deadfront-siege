#!/bin/bash
# UNSTABLE ISLE: double-click on the Mac. Rolls a fresh unstable isle and lands the survivor at its dock, windowed,
# with its 40-minute sink clock running. Extra args pass through, e.g. in Terminal:
#   tools/unstable_isle.command --seed=505 --template=swamp_55
# The window's notice (and the console) names the seed and template to replay it. See docs/current/unstable-isles.md.
REPO="/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul"
exec /Applications/Godot_mono.app/Contents/MacOS/Godot --path "$REPO/game" -- --lab=unstable_isle --skip-charcreate "$@"
