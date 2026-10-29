# dsc — HUDFALLOUT

Two standalone tests were red on canon after **NOHANDS** (8497c2c6 / merge 900ff50b) removed the
HANDS quick-slot (`HeldItemSlot`, `HuntHud.hands_spot()`) and **HUDTWEAK** (5f507698) moved the
vitals/badge/stomach geometry.

## What failed and why

**1. `game/tests/t_death.gd` — "the lab kit has a HuntHud".**
The test walks the lab kit's UI layer looking for `has_method("hands_spot")`. That method is gone
(replaced by `HuntHud.quick_row_y()`), so no child matched and `hud` stayed null. Every other HUD
test had already been migrated (`t_fieldhud`, `t_uinav`, `t_lootradial`, `t_hudrules`,
`t_treadmill`, `t_uigather`, `t_statusfx`, `t_weather`, `t_levelbar`, `t_starving`,
`t_levelbadge`); t_death was simply missed.

Fix: `game/tests/t_death.gd:36` now uses `c.has_method("quick_row_y")`. Prints `[t_death] PASS`.

**2. `game/tests/t_gather.gd` — `_test_hud_draw()`, check "set-up: the radial is laid out and the
HUD's own spot for the notice sits on it or the survivor".**

The HUD's notice placement is **fine**. With the gather radial open at 844x390 the rare notice was
drawn at `(333.0, 80.7)` and intersected none of the radial's labels/title/hexes or the survivor's
ring. The failing line was a stale *test precondition*, not the HUD:

- The test computed the "HUD-only spot" as
  `free_spot(cand, h.taken_rects(["notice","pill"]))` — i.e. it let the box *slide off* the HUD's own
  blocks — then asserted that slid box overlapped the radial or the survivor.
- NOHANDS/HUDTWEAK shrank the landscape-phone quick-row reserved zone in
  `ui_tokens.gd:hud_reserved()` from 308 px to 240 px and moved the vitals stack
  (`hud_layout.gd:vitals_rect` / `badge_centre` / `stomach_circle`), so that slid box now lands at
  y 214.5, below both the radial's "Herb Leaf" label (y 182.7) and the survivor (y 157.4–206.6).
- What the precondition existed to prove still holds for the **nominal** centre-column spot
  (`cand`, y 170): it sits on the survivor *and* the radial label, so `GatherFeedback.notice_avoid`
  is load-bearing.

Fix: the precondition now measures `cand` (the HUD's nominal spot, before the slide) instead of the
slid `old`. The behavioural assertion right after it — "the rare notice is drawn clear of its
labels, title, hexes, the plates and the survivor" — is unchanged. Negative check: temporarily
removing `avoid.append_array(notice_avoid(p))` from `GatherFeedback.notice_box` makes that
assertion fail ("a rare notice put on the survivor moves off them and their ring"), so the test can
still fail.

No gameplay or `game/scripts/ui/` code was changed.

## Other things done

- The worktree was 43 commits behind `origin/claude/mmo-overhaul` on entry; `git diff` against
  canon listed dozens of unrelated files and the verify scope gate rejected them. Fast-forwarded the
  worktree to canon (`d701a7fd`) first.
- After that merge the Godot class cache was stale (`StationState` parse errors, a null RNG in
  `roll_lot`/`roll_trait`) and t_gather failed an unrelated trait assertion. One
  `Godot --headless --path game --import` cleared it. Anyone merging canon data/scripts into a
  worktree should re-import before trusting a red test.

## Gates

`bash …/verify_hudfallout.sh` → `VERIFY PASS` (t_death, t_gather, t_fieldhud, t_ui, t_levelfx,
`tools/smoke.sh --no-import`).
