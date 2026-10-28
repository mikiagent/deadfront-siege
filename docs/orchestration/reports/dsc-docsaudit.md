# dsc — DOCSAUDIT: docs/current brought back in line with the code

Task: after tonight's merges (pet follow slots, STATUSFX boxes, tactical AI, the UINAV / UICHAR /
UICRAFT / UIANIMALS / UIMARKET screens, RAREATTR, COOKROLES), audit every page in `docs/current/`
against the code and fix what is stale. Docs only; no Godot runs. Never invent numbers: every value
was read out of `game/data/` or the script that owns it.

Verify: `verify_docsaudit.sh` — every `` `path` `` and every `` `func()` `` cited by a page must
exist, the report must exist, and nothing outside `docs/current/` + `docs/orchestration/` may change.
Result every checkpoint: **VERIFY PASS**.

## Per page

### README.md
- Before: the table listed 12 pages; `eyes.md`, `occlusion.md` and (after this run)
  `enemy-ai-template.md` were missing. Shot count said "31 shots" while several screens are captured
  into the report dirs.
- After: all 15 pages listed with a one-line State; the generated-page counts corrected to what the
  data holds (246 items, 180 recipes); new behaviours named in each State line (STATUSFX + nav menu on
  the HUD page, rare attributes on items, cook roles on recipes, brains/energy/follow slots on
  creatures, the real user dir on saves, the offline market on economy). Shot wording now says
  `docs/current/screens/` holds 31 WebP and the newer sheets live under `docs/orchestration/reports/`.

### ui-screens.md
- Before: `docs/orchestration/reports/uinav/b3_nav_menu_*.png` (and the `b4_claim_*` twin) were
  written as bare paths, which the gate reads as a truncated path; the `claim` entry appeared twice
  and the harbour paragraph was glued onto its heading; "The old BUILD bottom sheet is still reachable
  from code but no control opens it" was vague; the token section claimed "no sheet uses them yet"
  and that the Roboto Condensed TTF "is not in this branch".
- After: both citations point at the existing `docs/orchestration/reports/uinav/` directory; the claim
  entry is one entry with its description and shot; the BUILD note says what actually reaches it
  (`HuntHud._toggle_sheet(&"build")`, only the dev labs `ui_real_capture_lab.gd` and `web_soak.gd`);
  new intro paragraph maps every screen to the MENU nav menu and its `HuntHud.open_*` entry point and
  names the canvas layers; the token section is retitled "Tokens used by the restyled sheets" and says
  which files use them (`sheet_chrome.gd`, `uichar_chrome.gd`, `craft_ui.gd`,
  `market/market_screen.gd`), with the font note corrected (`game/assets/fonts/RobotoCondensed-Variable.ttf`
  ships).

### hud.md
- Before: claimed "Orders and Friends show greyed (no screen yet)", said Skills/Animals live in "the
  MENU sheet", said the market notice had no client event but not that nothing calls the hook, and
  carried the "not yet applied" token header plus the missing-font note.
- After: no entry is greyed (`NavMenu.DISABLED` is empty); Orders opens its own sheet; the Friends
  slot holds Island Market (ASSUMPTION, `nav_menu.gd` RIGHT); every entry listed with its `open_*`
  function and `open_menu` as the ‹ target; the rail line no longer claims a "MENU sheet"; the market
  badge says the hook has no caller; token section says the field HUD uses them and the sheets share
  them; font ships.

### creatures-capture-taming.md
- Before: "**The brains do not call these yet.**" under Energy — false since TACTICAL; no mention of
  `TacticalBrain` at all, so the brain list and `Creature._make_brain` were incomplete; the follow
  paragraph was right but missed `slot_arc_deg`, `step_aside_m` and the measured distances.
- After: energy section says `TacticalBrain` calls `try_special` / `can_use_special` / `can_sprint`,
  lists `sprint_states` including lunge and feint and pounce's 0.3 cost; new bullets for brain
  selection and for the tactical behaviour with real data numbers (ring 5.5 m, `attack_priority`
  combo/pounce/bite, per-move cooldowns, hop back-offs, pounce 0.8 s / 1.5×, combo 1.0/1.3/1.8,
  retreat 0.4, nature knobs); follow paragraph now carries `slot_arc_deg` 50°, `slot_size_mult`,
  `heel_mult` 0.7, `step_aside_m` 0.8 and the measured slots (3.72 / 5.16 / 3.36 m, Loyal 2.60 m).

### enemy-ai-template.md (new)
- The page existed only on `claude/mmo-tactical` (commit df113686) and here the *code* is merged but
  the page is not, so it was written from `game/scripts/creatures/brains/tactical_brain.gd` and
  `game/data/creatures/ai.json`. It documents who gets the brain, the state loop in the order the code
  runs it (strongest ready attack, cooldown on pick, filler beats, hop back-offs, pack gap, retreat),
  the deinonychus `tactics` table with its real values, hit times from `anim_events.json`
  (`bite_combo` hit_fracs 0.092/0.338/0.815, tell_fracs, pounce hit_frac 0.7), the optional clips and
  their fallbacks, the nature knobs (Timid 1.3 standoff /1.5 feint, Aggressive 0.7 cooldown /0.5
  feint), the player-side stun/roll/stagger interaction, the server `act.attack` scope, and how to add
  a class. The `pack_flanker` numbers in it replace the older draft's assumptions, which had already
  drifted (ring 6.5, pounce 2.5×, a sequences table the code no longer uses).

### recipes.md
- Before: the generated catalog showed the six `roled_*` rows with no explanation of what a role is.
- After: a "Cook roles (COOKROLES)" section before the tables: data `game/data/cook_roles.json`, code
  `game/scripts/items/cook_roles.gd`, the two `crafting.gd` seams (`role_accepts`,
  `apply_to_output`), the role→categories table, the inheritance rule as the code implements it
  (per-slot, from that instance, first wins, rare only when allowed, stored in `attributes.cooked_roles`
  / `cooked_buffs`), and the six recipes by name with their slot roles. The generated notice stays,
  with a line that this section is hand-written like the RAREATTR one.

### items-traits.md
- Verified: 246 items in `game/data/items.json` matches the header; `rare_trait.chance` 0.05;
  `by_material` covers 52 ids; 180 of 180 recipes mark slot 1 primary. The RAREATTR section was already
  correct — it gained the measured results (0 off-list and 0 double traits over 20 000 seeded gathers,
  from `t_rareattr.gd`) so the reader can see the rule is proven, not planned.

### saves-persistence.md
- Before: "Engine user dir: `game/override.cfg` sets `use_custom_user_dir=true` …". No such file
  exists in the tree or in any branch, and `game/project.godot` sets no custom user dir.
- After: the paragraph states the truth — no custom user dir, so Godot's default applies,
  `~/Library/Application Support/Godot/app_userdata/WildLands MMO/` on macOS, from `config/name`.

### inventory-bags.md
- Before: "a `Player` constructs `Inventory.new()`" (also tripped the gate's function check).
- After: "the survivor's `Inventory`, built once per `Player`". No number changed.

### server-contract.md
- Before: the `act.capture` row still said "on a knocked creature under 30% HP" — the pre-CAPTURE09
  rule.
- After: "inside `FieldTame.window_open` (stunned at any HP, or at or under 30 % HP)", matching
  `game/scripts/server/intent_handlers.gd:374,424`.

### economy-trading.md
- Added an "Island Market screens" section: the nav-menu entry (Friends slot,
  `nav_menu.gd`), `HuntHud.open_market(tab)`, ‹ back to the menu, the offline card in single player,
  and the harness that shows listings (`game/scripts/dev/market_harness.gd` + `LocalMarketClient`).
  Verified the engine/market-rules sentence and the XP table against the code; no number changed.

### survival-needs.md
- The fatigue-status table was right but the page never said what the other statuses in
  `game/data/statuses.json` are. Added a paragraph: 33 statuses in all, grouped (damage and capture
  conditions, target-side variants, food states, cleanliness) and the `fx` block link to the HUD page.

### controls.md, eyes.md, occlusion.md, world-biomes.md
- Checked against their code (`roll_rules.gd` + `combat_tuning.json` `roll`; `creature_eyes.gd`,
  `eye_trail.gd`; `occlusion.gd` constants; the generated biome tables). No stale claim found; no edit.

## What was not done
- No numbers were re-measured in-engine (the task said no Godot runs). Everything numerical is either a
  data file value or a figure the owning test prints, quoted from the report that produced it.
- The three generated pages (items-traits, recipes, world-biomes) need `gen_game_data.py` to learn the
  cook-roles and RAREATTR sections one day; until then both sections are marked hand-written, as the
  generator's own header asks.
- `docs/current/enemy-ai-template.md` was authored here because the tactical branch's copy never
  merged; whoever merges `claude/mmo-tactical` should keep this version (the merged code's numbers).
