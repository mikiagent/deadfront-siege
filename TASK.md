# TASK: four table-driven cases in game/tests/t_ui.gd for the HUD's moving-text layout

## Why
DEADFRONT (Godot 4.7.1, typed GDScript, project in `game/`) is played on landscape phones
(844x390 and 667x375 logical px). Reviewers saw moving HUD text drawn on top of fixed HUD blocks:
pickup toasts across the quest card, camp labels ("Tent", "Bonfire") over the quest text, a desktop
browser window 1200x480 getting the phone layout, and a new survivor showing no title. The reviewer
(Claude) fixed the layout code; you write the unit tests that guard it. `./verify_ui.sh` is the spec:
it runs t_ui on the real code and then on six deliberately broken copies, and each broken copy must
make t_ui fail.

## Read first (do not edit them)
- `game/scripts/ui/ui_tokens.gd`: `free_spot(box, taken, view)`, `_slide`, `layout_labels(items, view, avoid)`,
  `_covers`, `_hits`, `SPACE` (8), `LABEL_MAX_W`, `is_compact(view)`.
- `game/scripts/ui/level_display.gd`: `current_title(level)`, `player_level()`, `shown(stored)`.
- `game/data/skills/titles.json` (keys "1", "3", "5", "8", "12", "16", "20").
- `game/scripts/core/display_mode.gd`: `logical_size(window_px, device_scale, inset_px, handheld)`,
  `handheld()`, `DESIGN`.
- `game/tests/t_ui.gd`: the file you extend. Note its house style: `_expect(ok, message)`, the `UT`
  (ui_tokens.gd) and `LD` (level_display.gd) script vars loaded in `_process`, one `print("[t_ui] ...")`
  line per case, typed GDScript.

## What to write: edit ONLY `game/tests/t_ui.gd`
Add four functions and call them from `_process`, right after `_test_review_fixes()`. Each prints
exactly `[t_ui] ok <name> ...` (anything may follow the name) when every one of its checks held, and
adds a failure through `_expect` otherwise. Call ui_tokens and level_display through `UT.` / `LD.`
(already loaded); `DisplayMode` and `World` may be named directly (t_ui already does).

1. `_test_free_spot` (name in the ok line: `free_spot`). A TABLE (Array of Arrays or Dictionaries),
   one row per case, each row = box, taken rects, view, expected result; loop over it and compare
   with `UT.free_spot(box, taken, view)` exactly (Rect2 ==). Rows:
   - quest card: box Rect2(380,100,100,28), taken [Rect2(422,34,240,72)], view (844,390) -> Rect2(380,110,100,28)
   - already free: box Rect2(10,200,50,20), same taken and view -> the box unchanged
   - nearer upward: box Rect2(10,105,50,20), taken [Rect2(0,100,844,40)], view (844,390) -> Rect2(10,76,50,20)
   - no room: box Rect2(10,40,50,20), taken [Rect2(0,0,200,100)], view (200,100) -> Rect2() (no area)
   - chain down: box Rect2(10,125,50,20), taken [Rect2(0,100,200,30), Rect2(0,134,200,30)], view (200,400) -> Rect2(10,168,50,20)
   Also, for every row with an area result: the result is inside Rect2(0,8,view.x,view.y-16) and
   intersects no taken rect grown by 2 px. The `taken` arrays must be typed `Array[Rect2]`.
2. `_test_layout_avoid` (ok line name: `layout_avoid`). View (844,390), quest card
   `var quest := Rect2(422,34,240,72)`, items are Dictionaries {anchor, w, h, priority}:
   - a: one item anchor (540,120) w 80 h 22 priority 1, avoid [quest]: exactly one row comes back;
     its "rect" does not intersect quest.grow(2), is inside the view, and
     `absf(rect.end.y - anchor.y) <= (22 + UT.SPACE * 0.5) * 4`.
   - b: one item anchored INSIDE the card, (540,70), avoid [quest]: dropped (empty result).
   - c: the item of b with no avoid: placed (one row). This proves b dropped it because of avoid.
   - d: three items all anchored at (300,200) (w 80, h 22, priorities 3, 2, 1), avoid
     [Rect2(250,150,100,30)]: three rows; no two rects intersect, none intersects the avoid rect.
3. `_test_current_title` (ok line name: `current_title`). A TABLE level -> expected title, compared
   with `LD.current_title(level)`: 0 -> "", 1 -> "Venture into the World", 2 -> "Venture into the World",
   3 -> "Castaway No More", 4 -> "Castaway No More", 5 -> "Camp Builder", 19 -> "Wild Lands Veteran",
   20 -> "Frontier Legend", 99 -> "Frontier Legend". Then a new survivor: save `World.pioneer_level`,
   set it to 0, expect `LD.current_title(LD.player_level()) == "Venture into the World"` (the orchestrator
   ruled the level-1 title is held from character creation), restore the saved value.
4. `_test_desktop_short_window` (ok line name: `desktop_short_window`):
   - `DisplayMode.logical_size(Vector2i(1200, 480), 1.0, 0.0, false) == DisplayMode.DESIGN` and
     `UT.is_compact(Vector2(that))` is false (a desktop browser window is not a phone);
   - `DisplayMode.logical_size(Vector2i(1200, 480), 1.0, 0.0, true)` IS compact (the same shape on a
     touchscreen is a phone held sideways);
   - `DisplayMode.logical_size(Vector2i(844, 390), 1.0, 0.0, true) == Vector2i(844, 390)`;
   - `DisplayMode.handheld()` is true in this native (non-web) run (the labs use --resolution 844x390).
Keep each function short, typed, with a one-line `##` comment saying what it guards. Do not change
any existing case.

## Rules
- Edit ONLY `game/tests/t_ui.gd`. Do not touch `game/scripts/**`, `game/data/**`, `run_all.gd`,
  `project.godot`, `override.cfg`, the verify script or this file.
- If a case cannot pass on the real code, do NOT weaken it and do NOT edit the code under test:
  write the case, the output and your reasoning in `DSC_NOTES.md` at the worktree root and say so in
  your last message.
- Run Godot ONLY via the slot wrapper with a timeout, from the worktree root:
  `/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/1899b1df-f06b-4b94-91be-9e3f3c22081d/scratchpad/gslot.sh perl -e 'alarm 240; exec @ARGV' /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --path game --script res://tests/t_ui.gd`
  Never pass --editor, never run windowed, never play audio, never run --import.
- Commit with `git add game/tests/t_ui.gd` only (never `git add -A`), message ending
  `Co-Authored-By: DeepSeek (dsc) <noreply@deepseek.com>`. Never push.

## Milestones
1. Cases 1 and 2; clean run prints `[t_ui] PASS`. Commit.
2. Cases 3 and 4; clean run PASS. Commit.
3. `./verify_ui.sh` prints `VERIFY PASS`. Fix the test (never the code under test) until it does.
