# UI gauntlet pass 2: fix the defects seen in the redesign screenshots

Filed by Claude Code on 2026-09-21 after reviewing commit 7face69 (Durango-style UI redesign)
at `/tmp/deadfront-ui-shots/*.png`. Presentation only. Read `GAUNTLET.md`, `HANDOFF.md` and
`OPUS-UI-REDESIGN-PROMPT.md` first; the Durango references DO exist in `docs/reference/`
(the previous run said they were missing; it looked in the wrong place). Open them.

## Defects to fix, in order

1. **World labels overlap.** `radial_1600x900.png`: "Stone  Lv. 100" is drawn over "Ancient Tr…"
   at the same spot. The collision avoidance added to `hunt_hud.gd` is not separating labels
   that share an anchor. Labels must stack or offset so every label is fully readable; the
   Workbench / Cargo Warp collision named in `UI-REDESIGN-AUDIT.md` must be fixed in the real
   home camp, not only in the lab. Add the two-labels-one-anchor case to `ui_screenshot_lab`.
2. **Rail labels cross the hex outline.** `hud_1600x900.png` and `hud_390x844.png`: MENU /
   ANIMALS / BUILD / SKILLS are drawn across the bottom edge of their hexes so the outline cuts
   through the text. Put the label fully inside the hex (glyph above, label below the glyph,
   both inside the border) or fully below the hex with clearance; keep the 64 px target.
3. **Desktop vitals are tiny.** `hud_1600x900.png`: the four bars are ~180 px wide with ~11 px
   numbers. Use `UiTokens.body` / `UiTokens.meta` sizes at 1600x900 and give the panel room
   (the audit calls this "tiny desktop typography").
4. **Character screen is two-thirds empty at 1600x900.** `inventory_1600x900.png`: the
   content sits in the top third. Use the space: larger slot cells (at least 64 px), stat rows
   with more presence, the equipment grid vertically centred against the bag. Keep 5x4 + 3x3.
5. **Craft list row metadata is ellipsised** ("Stone Work Knife  Lv 60 ·…"). Reserve width for
   `Lv 60 · 3.0s` so it never truncates at 1600x900; ellipsis only on the recipe name.
6. **Animals growth list is cut by the button bar** (`animals_1600x900.png`, "Melee Attack"
   half hidden). Give the scroll container a bottom margin equal to the bar height.

## Acceptance

- Re-run `ui_screenshot_lab` windowed at 1600x900 and 390x844 for every screen; inspect the
  PNGs yourself and fix the first visible defect before reporting.
- `tools/test.sh` prints `[tests] PASS`, `tools/smoke.sh` prints `SMOKE PASS`, `ui_family_lab`
  and `ai_validation_lab` pass.
- Stage only files you changed; never `git add -A`. Do not deploy; report the commit hash.
- Report: `docs/orchestration/reports/cursor-ui-gauntlet-2.md` with before/after screenshot
  paths. Commit message: `UI gauntlet 2: label collisions, hex rail labels, desktop type sizes,
  character screen density, craft row width, growth list margin`.
