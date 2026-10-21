# Task: shrink the web download to 180 MB or less with no visible loss - WEBPACK

Context: DEADFRONT, Godot 4.7.1 (project `game/`), shipped as a web build. The export pack is 255 MB, over the 220 MB ceiling
(W1-WEB); the last exports used PAYLOAD_MAX_MB=260. Biggest parts: survivor ~69 MB (game/assets/characters/survivor),
nature/generated ~51 MB (game/assets/nature/generated), resources/generated ~33 MB. A first visit downloads all of it.
Read tools/export_web.sh, tools/check_export_payload.py and game/export_presets.cfg (the Web preset) first.

## Goal
`tools/export_web.sh` with the default ceiling prints a payload line of 180 MB or less, the game looks the same, and nothing
the game loads is missing.

## Allowed levers (in this order)
1. Texture import settings for what the web build ships: VRAM-compressed formats suitable for WebGL2 (check what Godot 4.7
   supports for the Web preset), mipmaps, and a max size by role (characters/creatures 2048, props/nature 1024, icons as they
   are). Change the .import files (or project defaults) - do not edit the source images unless a source is absurdly large
   for its screen size (then downscale with ffmpeg and say so).
2. Leave out files the game never loads from the Web preset (prove each with a grep for its path/uid in game/ and a boot).
3. Dedupe identical files.
Do NOT change meshes, rigs, clips, scenes, code, or the desktop look.

## How to run things (exactly)
- Godot only through the slot limiter with an alarm, output to a file (never piped into tail/head/grep), bash timeout_ms =
  alarm*1000 + 60000:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 900; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --import > /tmp/wp_import.log 2>&1`
- Export: `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 2400; exec @ARGV' bash tools/export_web.sh > /tmp/wp_export.log 2>&1` (timeout_ms 2500000), then read the `[payload]` lines.
- Shots need a window (never --headless): `... gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --path game --resolution 1600x900 --rendering-method gl_compatibility -- --lab=home_lab --tod=0.45 --shot=/tmp/home.png --shot-delay=6 > /tmp/home.log 2>&1` and the same with `--cam-size=10 --shot=/tmp/close.png` for the close-up.
- Compare with the baselines: `ffmpeg -hide_banner -i /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/webpack-base/home_1.png -i /tmp/home.png -lavfi ssim -f null - 2>&1 | grep -o "All:[0-9.]*"` (two base runs score 0.9994; the gate is 0.97). Also LOOK at both images.

## Milestones (write them into .dsc/PLAN.md; call milestone_done after each)
1. Measure: a table of the 30 largest files in the export pack with their role and on-screen size; the plan per group.
2. Texture import settings: --import, shots pass SSIM >= 0.97 against both baselines.
3. Export: payload <= 180 MB; unused files proven and left out.
4. Report `docs/orchestration/reports/dsc-webpack.md`: before/after sizes per group, SSIM numbers, what was left out and why.

## Constraints
Keep game/override.cfg. Never touch other folders under .claude/worktrees/, the owner's save, or ~/Documents/deadfront. Do not
push, merge or deploy. No new dependencies. Known trap: an import of thousands of textures takes minutes - run it once per
batch of changes, not per file.
Verify command: `bash /private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/dsc/verify_webpack.sh`.
