# INVUI report (spec 13: Durango Bag, Character -> Gear, Equipment / My Info)

Branch `claude/mmo-invui` (work tree `.claude/worktrees/mmo-invui`), stacked on `claude/mmo-w2-inv`. Design:
`docs/orchestration/mmo/invui-spec.md`. Hooks: `docs/orchestration/reports/claude-mmo-invui-hooks.patch` (created by B1 with
the first hooked change; the design step changes no file outside INVUI's own).

## Design step (2026-10-20)

Shipped:
- Base sync: W2-INV is not merged into claude/mmo-overhaul, so `claude/mmo-w2-inv` (5ff239a6) was merged; its hooks patch
  is unchanged since "Apply W2-INV hooks (INVUI base)" (3ecb02ca), so nothing was re-applied.
- `docs/orchestration/mmo/invui-spec.md`: component tree with files, palette / type scale / metrics, procedural texture
  plan, API contract, data each element reads, commands and the exact hook list, screen layouts, optional save fields,
  22 assumptions with doc checks, the measurable acceptance checklist and the B1-B4 phase plan.
- `game/data/inv_ui.json`: sort keys, filter groups, spec 04 attribute classes, 3x3 equipment layout and silhouettes,
  preset unlock levels, power groups, picker warn level.
- `game/scripts/dev/bag_ui_lab.gd` + `game/scenes/dev/bag_ui_lab.tscn`: deterministic survivor, bag 91 / 100 (berries
  Lv. 12/25/42 with a rare trait, raptor bones Lv. 45/60 with Firm / Low Density / Black Sheen, herb leaves, a 4-slot
  caged zebraceratops, workbench kit, knife, club, slingshot, pick, axe, shirt, cuirass, helm, forager set), 10 NEW,
  2 locked, hood + vest worn, pick held, a bonded raptor with 3 cargo items, a 60-slot storage box; `--screen=bag | inspect
  | character | equipment | storage | cargo | picker`; headless contract check and per-screen open times.
- `game/tests/t_invui.gd`: spec 13 section 23 items 1-20 against the section 4 contract.

Checks run on this commit:
- t_invui: exit 1, "[t_invui] 20 failures" (expected skeleton: every item fails, e.g. "FAIL 3 individual: not built yet
  (inventory_grid.gd, inventory_slot.gd)", "FAIL 12: a container opens the shared Bag | Storage split view"), 0 SCRIPT ERROR.
- bag_ui_lab headless: exit 1, "[bagui] seed bag 91/100 worn=2 new=10 locked=2" then "FAIL InventoryUI.open_bag exists"
  etc. (expected skeleton).
- Base shot (old grouped bag, for the A/B "before"): 1600x900 gl_compatibility, opened and looked at: 5-column grouped
  grid with symbol icons and "×N" captions, CHARACTER header, inert GEAR 1/2/3 row.
- Base shot at 844x390 gl_compatibility, looked at: the old bag scrolls, profile column crowds the grid.
- Gates on 8f3d8a3d (merged W2-INV + design files): t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_inventory,
  t_items, t_lighting ("[t_light] PASS"), t_occlude, t_player, t_save (5 deliberate SCRIPT ERRORs), t_server_domain,
  t_srvdom, t_structart, t_tame, t_ui, t_web all PASS; run_all "[tests] PASS"; tools/smoke.sh --no-import "SMOKE PASS";
  no new Godot-*.ips (25 before and after). t_uiicons FAILED on the inherited W2-INV hook line
  "inventory_ui.gd:444 symbol ‹ (U+2039) has no icon mapping"; fixed here ("< All"; the grouped view goes in B1) and
  rerun: "[t_uiicons] PASS ids=169 files=114 ...".

Assumptions: spec section 9 (1-22). Owner questions (non-blocking): spec section 12.

Next (B1): build the Bag and inspection per spec section 11, create the hooks patch, turn t_invui 1-11/18/20 green.
