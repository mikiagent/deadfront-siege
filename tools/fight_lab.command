#!/bin/bash
# FIGHT LAB: double-click on the Mac. The creature lab in GOD mode (no damage, no death, endless energy),
# windowed. NEXT (or T) spawns the next modelled species; GOD (or G) toggles god mode. See docs/current/fight-lab.md.
REPO="/Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-overhaul"
exec /Applications/Godot_mono.app/Contents/MacOS/Godot --path "$REPO/game" -- --lab=creature_lab --god --skip-charcreate
