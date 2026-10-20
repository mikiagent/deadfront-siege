# W2-SKILLS (claude/mmo-w2-skills): Durango 1-60 skill trees

Scope (HANDOFF §4): durango-prompts 03 + 09 + 11 + 12. Durango 1-60 levels, Lv1 AUTO nodes, Animal Handling I-IV,
the Processing tree, the 918-node table imported as data with each node marked functional / partial / defined,
recipe-gated progression, and survivors that start at Lv. 1.

## What shipped

- **Trees start at Lv. 1.** `SkillState.MIN_LEVEL = 1`. A new survivor reads Lv. 1 in every tree (it showed Lv. 0 before).
  The player badge and XP line already read Lv. 1 on the base through `LevelDisplay`.
- **Character level 1-60 caps the trees (spec 03).** `character_level()` is now the one player level
  (`LevelDisplay.player_level()`, fed by every skill XP grant). Before, it was the average of the tree levels.
  A tree cannot level past the character level. At the cap the XP bar fills and waits. `World.pioneer_changed`
  releases it. The occupation's Lv. 20 head start is exempt (ASSUMPTION). The cap can be switched off with
  `category_cap` in trees.json.
- **Lv1 AUTO nodes.** `"auto": true` nodes (0 SP) are learned once their level is reached: at creation, on
  level-up, on occupation, and on load. They cannot be refunded. Examples: Rope (Basic Processing), Stone Blade,
  Leaf, Branch, Bush, Fruit I, Log I, Bug I, Pebble, Mud I, Stalk, Bone I, Roll, Leaf Outfit, Footwraps, Leaf Hat,
  Corn and Apple Tree.
- **Animal Handling I-IV (spec 09).** These reuse the save ids `animal_management_1..4`. The values follow the
  spec: Survival 35/45/55/60, SP 4/5/5/6, chain I->II->III->IV, and I requires Capture Technique I ("Animal
  Taming"; ASSUMPTION). `SkillRules.bonded_capacity()` = 3 + one per learned node, up to 7.
  `SkillRules.can_bond(count)` blocks a new bond at the cap. A reset keeps existing pets.
- **Processing tree (spec 11).** It holds every node the spec documents: Normal Nail, Leather Strap, Charcoal,
  Dry Leather, Peeled Bark, Handicraft I-V (+4 Handicraft each), Trimmed Material, Extended Fabric, Glue, Gem
  Extraction, Cord, Waterproofed Material, Refined Ore, Metalworking I-IV (+4 Metal Processing each), Adhesive
  Accessory, Dry Rubber, Metal Links, Copper Alloy, Fiber-Tanned Material, Compressed Material, Precision
  Processing and Processed Debris. The PRD nodes stay alongside them. `SkillRules.ability(sk, "handicraft" |
  "metal_processing" | "slaughter" | "stealth")` gives the totals.
- **Spec 12 nodes in the other trees:** Stealth I-V, Mud II, Wild Seed I, Obsidian, Marble, Alum, Long Branch,
  Leather I/II, Bone II, Feather, Skull I, Teeth I/II, Horn, Slaughter I-V, Barrage + Barrage Damage I-III, Roll
  Duration I-III, the saw/handle/mortar/bow lines, Straw Shoes, Leather Sandals, Till Small Field (Lv1, 1 SP) and
  Till Large Field (Lv25, 3 SP).
- **Recipe gates.** `SkillRules.recipe_block(sk, recipe_id)` returns "" when the recipe is open. Otherwise it returns
  a message like "learn Charcoal (Processing Lv. 10, 1 SP)". Gated recipes: twine/rope (Rope, AUTO),
  improvised_stone_knife (Stone Blade, AUTO), hide_strap (Leather Strap), charcoal (Charcoal), dried_hide (Dry
  Leather), field_small (Till Small Field) and field_large (Till Large Field). This becomes real once hook H1
  lands; the craft card already shows `progression_block` text as the lock reason.
- **Refunds.** A node another learned node needs cannot be refunded. A refunded survival node clears its Data
  mirror. This fixes a bug: refunding Capture Technique used to leave net capture on.
- **SP come from character levels (spec 03; coordinator decision 2026-10-20).** Tree level-ups pay nothing.
  Each character level 2..60 pays `sp_budget` (10/12/14/16 by band, 720 SP at Lv. 60). The occupation's Lv. 20
  grants levels and auto nodes but no SP (ASSUMPTION). SP are always derived:
  `sp_earned = paid_for_level(character level)` and `sp_available = max(0, sp_earned - cost of learned nodes at
  today's prices)`. They are recomputed on load, on every `World.pioneer_changed`, and for saves with no skills
  block. A saved `sp_earned` is never trusted.
- **Catalog.** `trees.json.reference` holds the spec-12 counts: 13 categories that sum to 918 nodes, plus the
  Toxic Oil Islands unlock list as an optional, defined-only entry. **212 of 918 nodes are imported: 17
  functional, 19 partial, 176 defined.** Every node has `status`, `source` (spec09/11/12 or prd7), `effects` and
  `sp_assumed` where the pack gives no SP.
- **Skills sheet (trivial, listed):** node rows show the Durango name and "AUTO" in place of "0 SP". Owned auto
  nodes show a disabled "Learned" button in place of "Refund".

Files: `game/data/skills/trees.json`, `game/scripts/skills/skill_state.gd`, new `game/scripts/skills/skill_rules.gd`,
new `game/tests/t_w2_skills.gd`, `game/scripts/ui/skills_sheet.gd` (trivial). Migration test fixtures:
`game/tests/fixtures/save_v3_golden.json` and `save_v3_away_golden.json` (skills_v2 only), plus one expectation
in `game/tests/t_save.gd`.

## Save format change (owner decision to flag)

skills_v2 gains `"rev": 2` and `"sp_earned"` (informational). A rev-1 save migrates when it loads:
- A level stored as 0 reads as Lv. 1.
- SP are recomputed from the character level.
- Every learned node is kept and re-priced at today's costs.
- If the learned nodes cost more than the character level has paid, the save keeps them all and shows 0 SP
  until the character catches up (ASSUMPTION, per the coordinator).
- AUTO nodes are learned.
- Nothing is deleted.
The goldens were migrated by a script that mirrors `from_dict`, and t_save's "golden survives load + save
unchanged" passes, which proves the GDScript migration and the script agree. In t_save's forged-save check,
Stealth I (Survival Lv. 10, no prerequisite, per spec 12) is now reachable, so the expectation is
`[island_access_15, stealth_1]` with sp_spent 7.

## Acceptance (exact lines, after `git merge claude/mmo-overhaul` @ 1c89134a)

- `[t_w2_skills] catalog 212 of 918 nodes: functional 17, partial 19, defined 176`
- `[t_w2_skills] PASS` (9 sections, including the H6 checks when H6 is applied). The test fails when it should:
  - With `bonded_base` set to 4 it printed `FAIL capacity 4, 5, 6, 7 (got [5, 6, 7, 8])`.
  - With the old per-tree SP award restored it printed `FAIL character Lv. 5 pays levels 2-5 (40 SP), the
    released tree levels pay nothing`, `FAIL three trees at Lv. 10 pay no SP of their own (earned 90, want 90)`
    and `FAIL character Lv. 20 pays its SP with no tree XP (190)`.
- `[tests] PASS` (run_all)
- Every other test prints PASS: t_ai, t_build, t_canim, t_combat, t_harbour, t_iconart, t_items, t_light,
  t_lighting, t_occlude, t_player, t_save (its 5 SCRIPT ERRORs are its own deliberate aborts), t_server_domain,
  t_srvdom, t_structart, t_tame, t_ui, t_uiicons, t_web.
- `tools/smoke.sh --no-import` -> `SMOKE PASS`

**Final code at edd86f5f with hooks H1-H6 applied temporarily (not committed):**
- run_all `[tests] PASS`, all 21 t_*.gd PASS, and t_w2_skills ran its H6 section.
- `SMOKE PASS`.
- Labs PASS: craft_lab, kitchen_lab, capture_lab (bonded+=2), pets_lab 5/5, raid gear probe and progression
  probe. ui_family_lab printed `unlimited=true`, which with H5 means its cap-of-3 check holds.
- Earlier, with H1-H5 on the pre-SP-change code: `[uireal] PASS screens=hud,craft,skills,...` at 1600x900 on
  gl_compatibility. t_srvdom and t_server_domain had failed with H3 alone (a Lv. 1 melee hit for +1 %); H4 fixes
  that.

Screenshots looked at (scratchpad `w2skills/shots/`):
- `desk/skills_processing_1600x900.png`: Processing Lv. 1. Rope · Lv. 1 · AUTO shows Learned, the
  Durango-named nodes show their lock reasons, and SP is 0.
- `phone/skills_844x390.png`: every tree reads Lv. 1.
- `phone/skills_survival_844x390.png`: Stealth I, Mud II and Wild Seed I with their level locks.

## Integrator hooks (`docs/orchestration/reports/claude-mmo-w2-skills-hooks.patch`, `git apply` checked)

- **H1** `game/scripts/items/crafting.gd` `progression_block()`: check `SkillRules.recipe_block` first. This makes
  the recipe gates real. station_craft and craft_ui already route through `progression_block`.
- **H2** `game/scripts/core/data.gd` `bonded_cap()`: `SkillRules.bonded_capacity(PlayerRegistry.local().skills)`,
  or 3 with no player. This replaces "unlimited", per spec 09. It reaches field_tame.apply_feed and
  player_pets.bond_from_inventory. **taming_pen.gd:132 bonds without any cap check.** W2-BREED owns that file;
  it should call `Data.bonded_cap()` / `SkillRules.can_bond`.
- **H3** `game/scripts/server/character_state.gd`: a missing tree defaults to `SkillState.MIN_LEVEL`, not 0.
- **H4** `game/scripts/combat/hunt.gd` (melee and ranged) and `game/scripts/server/intent_handlers.gd` (melee):
  per-level damage and crit bonuses count from Lv. 1 (`level - SkillState.MIN_LEVEL`), so balance is unchanged.
- **H5** `game/scripts/dev/ui_family_lab.gd`: it asserted an unlimited roster. It now expects 3.
- **H6** `game/scripts/core/save_sanitizer.gd` `_skills(sv, pioneer_level)`:
  - The node-purchase budget is the SP the character level paid.
  - For a rev-1 save, the budget is what its tree levels paid under the old award, so the migration never drops
    a learned node.
  - `sp_available` is clamped to `max(0, character SP - spent)`.
  - The caller passes the clamped `pioneer_level`.
  - Known gap: a forged rev-1 save can keep nodes up to the old per-tree budget. It still gets 0 extra SP,
    because SkillState derives SP.

Wanted from other packages:
- W2-PROCESS reads `SkillRules.ability(sk, "handicraft" | "metal_processing")`. That turns Handicraft and
  Metalworking from partial to functional.
- W2-BREED shows "n / cap" from `Data.bonded_cap()` in the pets UI.

## Assumptions (`# ASSUMPTION` in code or data)

- The occupation's Lv. 20 is exempt from the character-level cap.
- XP over the cap is dropped once the bar is full.
- Animal Handling I requires Capture Technique I.
- SP values marked `sp_assumed`: Stealth II-V, Slaughter I-V, Barrage Damage I-III, Handicraft II-V,
  Metalworking I-IV, level 45/50/60 Processing nodes, the makeshift shovel/hoe and Standard Bow.
- The occupation's Lv. 20 grants no SP.
- A migrated save that is over budget keeps its nodes with 0 SP available.

## Open owner decisions

1. ~~Source of SP~~. Decided: per character level, per spec 03. Implemented, with H6.
2. **The 918-node table is still missing (decided: keep the 212 nodes).** The source table (kghj76138.github.io/durango-homecoming-guide/en/skills.html) returned 404 on
   2026-10-20, and the Wayback Machine was offline. Only the nodes the pack names are imported; the counts are
   recorded. Supply the table (or another copy) to finish the import.
3. ~~The save rev 2 bump~~. Approved as built.

## Left (not done)

- Research timers (spec 03 table).
- Daily refund limits.
- Career Guides.
- Attribute service.
- Server-side recipe gates and node purchases online: CharacterState keeps levels only (W3-SRVACT).
- Gathering, butchering and tailoring effects of the defined nodes, owned by W2-GATHER, W2-BUTCHER, W2-TAILOR,
  W2-ACTION and W2-CRAFT.
- Stealth Ability in the AI detection service.
- skills_lab still prints a level-1 gathering, because the cap holds it at character Lv. 1. The lab only
  prints and asserts nothing.

No labs to register. No dsc worker was used: the import was a single scripted transform, and per the owner's
2026-10-20 note dsc is off unless asked.
