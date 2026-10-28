# LOOTRADIAL: carcass looting uses the gather radial

Branch `claude/mmo-lootradial` (from `claude/mmo-overhaul`). No credits spent.

## What shipped
- A carcass opens `GatherRadial.open_carcass` (tap, BUTCHER, or its new HUD name pill): one hex per part
  (`Corpse.radial_options`), seconds per cut on top, units on the carcass at the bottom, a gold ★ on a
  rare part, a red ⊘ and the reason on a locked part's label, the budget on the title ("2 cuts left").
- Picking a hex starts `Corpse.begin_cut`; the hex pie-fills from the carcass's clock, the others lock,
  the part lands via `Player.toast` (top-middle gain row), and the fan re-reads the carcass and stays open.
- `butcher_picker.gd` deleted; the carcass "Loot · <species>" plate label (creature_plates) replaced by a
  HudPills pill. A carcass with no part table still opens the chest screen.
- Shared radial fixes: labels avoid other labels (weighted 4x) with extra side-row candidates; desktop
  label cap 340 px (phone stays 148).
- Owner rule (one per harvest), applied to butchering: each cut yields exactly one instance; knife tier and
  Butchering level shorten the cut (`loot_tables.json butcher.cut_speed_*`, replaced `count_bonus_*` and
  `no_knife_count_mult`) and raise rare odds.

## Assumptions
- One-per-harvest applies to butchering (coordinator relay of the owner's gather rule).
- Cut speed: 1.6 s / (1 + 0.15 per knife tier above stone + 0.01 per Butchering level) (the old count numbers).
- Part quality = rare-part odds only; material level stays the carcass's level.
- A part's rare roll replaces the cut's one instance (CarcassParts.cut). In the live corpse roll a base and
  rare row of the same id (protoceratops bone) can still put two instances on the carcass; a cut takes one.

## Gates
t_butcher, t_lootradial (new), t_uigather, t_gather, t_levelfx, t_ui, t_fieldhud, t_player PASS;
run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.
Shots: `docs/orchestration/reports/lootradial/` (desktop crops downscaled to 760 px, 4-bit posterised to fit 300 KB).

## Known
- At 844x390 a locked part's label is cut ("Dense Bone · Needs…") and one can touch the LOOT hex.
- Dev labs `hunt_lab.gd` / `bot_survivor.gd` still use the old per-slot `loot_options` take (kept; t_player uses it).
