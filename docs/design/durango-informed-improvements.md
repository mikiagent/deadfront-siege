# Durango-informed improvements for Deadfront Siege

**Date:** 2026-10-16
**Inputs:** the five Durango research notes in `research/`, and a read of Deadfront's current code on main.
**Rule:** each proposal borrows a design *shape* that the Durango research showed works. Every number below is our own starting value, to tune in playtests. Nothing here copies Durango's formulas, data or code.

Ranked by value for the effort. File references are to `game/`.

## 1. Fatigue that scales with level gap and climate

**Durango:** fatigue was the session governor. Base rate fell as the player out-levelled the island, work actions cost less than combat, and climate added fatigue in proportion to the resistance shortfall.

**Deadfront today:** flat per-activity rates. Walking, gathering, combat and a flat climate rate are fed in from `scripts/player/player.gd` around lines 463, 1002, 1059 and 1739. Island level and resistance don't affect them.

**Change:**

- Multiply every fatigue gain by a **level-gap factor** in `Vitals.add_fatigue`, using the existing `ProgressionScaling.zone_pressure`. A starting point: +6% per level the island exceeds the player, −4% per level below, floored at 0.5.
- Replace the flat climate rate with **shortfall × rate**, where shortfall is the climate's requirement minus the player's resistance from `data/world/climates.json`, clamped at zero.
- Charge gathering and crafting by the **square root of their energy cost**, and combat linearly, so work tires you slowly and fights quickly.

**Why:** players drift toward islands that suit their level and gear, with no hard lock.

## 2. A fatigue breakdown panel

**Durango:** a panel named every cause of the current fatigue rate and its remedy.

**Deadfront today:** `Vitals.fatigue_log` already records fatigue by source, but no UI reads it.

**Change:** add a panel opened from the HUD fatigue gauge in `scripts/ui/hunt_hud.gd`. It shows the share per source over the last few minutes and one remedy line per source, such as "climate: wear warmer clothes or rest by a fire".

**Why:** it's cheap because the data exists, and it turns fatigue from a punishment into a decision.

## 3. A stagger meter instead of a groggy coin flip

**Durango:** every move filled a stagger meter on the target. Crossing sections led to groggy, then knockdown. Tackle did almost no damage but huge stagger, and that was the capture setup.

**Deadfront today:** groggy is a status applied directly by a hit or the body tackle in `scripts/combat/hunt.gd` lines 166 and 207.

**Change:**

- Give `Creature` a `stagger` gauge with a max from species data. It decays when the creature isn't being hit.
- Give each player move a `stagger` value in data: light for basic hits, high for heavy hits, very high for tackle.
- At 100% apply groggy, and a further heavy hit while groggy applies knockdown. Show the gauge under the creature's health bar in `scripts/ui/creature_plates.gd`.
- Keep the T. rex exemption in `status_effects.gd` line 36, or give it a much larger stagger pool and a short knockdown.

**Why:** capture becomes a skill the player can see building, not a lucky proc.

## 4. Directional damage and armoured fronts

**Durango:** most animals took more damage from behind. Armoured-front animals reversed that. Hit location followed direction.

**Deadfront today:** `hunt.gd` `_is_behind()` only adds crit chance.

**Change:**

- Add `damage_by_side` to the archetypes in `data/creatures/ai.json` with front, side and back multipliers. Starting values: raptors 0.85, 1.0 and 1.2. Ceratopsians and Ankylosaurus 0.7, 1.0 and 1.0, with the extra damage on the flanks instead.
- Show the multiplier as the floating number's colour so players learn it.

**Why:** positioning matters without twitch skill, and it suits touch controls.

**Later:** body parts. A leg hit past a threshold applies a limp, slowing the creature. That needs a limp clip per rig, so it waits for the animation pipeline.

## 5. Taming odds instead of guaranteed success

**Durango:** taming opened only at low health, used an S-curve on the player-to-animal level gap, and rewarded weakening the animal further.

**Deadfront today:** `scripts/pets/field_tame.gd` always succeeds and rolls a random grade.

**Change:**

- Open the tame action at 30% health or below.
- Success = S-curve on (Survival level − creature level), times a bonus for lower remaining health. Starting point: 50% at an even level gap, 85% when 10 levels ahead, 10% when 10 levels behind.
- On failure the animal recovers a little stagger and flees briefly. Show the odds on the tame button.
- Feed the same level gap into the grade roll, so a better-prepared player gets better grades.

**Why:** capture tiers and Survival levels become meaningful, and the grade feels earned.

## 6. Craft outcomes from skill versus difficulty

**Durango:** each craft compared difficulty to ability. Failure rose with the square of the gap, and great success was a separate small roll.

**Deadfront today:** only food can fail, through `burn_on_fail` in `scripts/items/crafting.gd` line 158. Everything else always succeeds.

**Change:**

- Add an optional `difficulty` to recipes in `data/recipes.json`.
- Failure chance = (max(0, difficulty − skill) / 30)², capped at 60%. Failure consumes some secondary materials and never the primary one.
- Great success chance = 3% + 0.2% per level above difficulty, capped at 12%. It adds +2 item levels or one extra process count.
- Show both odds on the craft card in `scripts/ui/craft_card.gd`.

**Why:** levelling a crafting skill has a felt payoff, and great success gives a reason to craft the same thing again.

## 7. One recipe, several outputs by primary material

**Durango:** a single axe recipe produced a stone, bone or metal axe depending on the main slot's material.

**Deadfront today:** each recipe has one `output.id`. Material tier is stored as an attribute in `build_output`.

**Change:** allow `outputs_by_primary` in a recipe, keyed by primary material category or tier, falling back to `output`. Each output can have its own mesh and icon.

**Why:** fewer recipes in data, and players see a visibly better tool when they use a better material.

## 8. A skill curve and research gates

**Durango:** skill experience needs rose slowly. From skill level 20, every five levels required a timed research step, from minutes up to days, with a notification when it finished.

**Deadfront today:** `xp_to_next` in `scripts/skills/skill_state.gd` is a linear placeholder marked as an assumption. There are no research gates.

**Change:**

- Use a gently rising curve, for example 20 × 1.06^level, and tune it with the existing survivor bot in `scripts/dev/bot_survivor.gd`.
- Add research gates at 20, 30, 40 and 50 only. Use shorter times than Durango's: 10 minutes, 1 hour, 4 hours and 12 hours. Practising the skill during research shortens it.

**Product decision needed:** research timers are a mobile return-later hook, but long ones drew complaints in Durango. Decide whether Deadfront wants them before building this.

## 9. Creature stats as level curves in data

**Durango:** health and stagger grew faster than linearly with level, while offence grew linearly, all scaled by an island difficulty factor.

**Deadfront today:** species have flat stats in `data/creatures/*.json`, and `ProgressionScaling.level_multiplier` scales everything by 8% per level.

**Change:** split the multiplier. Health and stagger use a curve such as (1 + 0.06 × level)², and attack uses the existing linear 8%. Put both rates in `data/world/rules.json` so they can be tuned without code.

**Why:** high-level creatures become tanky without one-shotting the player.

## 10. Onboarding triggers and UI pointers

**Durango:** onboarding ran as per-island event flows, with triggers for moments like arriving at a lake or hitting full fatigue. A spotlight pointed at the exact button.

**Deadfront today:** `scripts/core/objectives.gd` runs a clean linear list from `data/world/objectives.json`. It has no triggers and can't point at UI.

**Change:**

- Add optional `trigger` objectives that interrupt the main list once: first full fatigue, first bleed, first night, first time over-levelled.
- Add a `point_at` field naming a HUD element or station. The HUD pulses that element while the step is current.

**Why:** players get help at the moment they need it, and objectives can show where to tap, not just what to do.

## 11. Stacking death penalty

**Durango:** repeated deaths in a row restored less each time, and dying twice was a spiral to avoid.

**Deadfront today:** `Vitals.revive` restores 50% health and caps fatigue at 50% every time.

**Change:** track consecutive deaths, resetting after 10 minutes alive. Revive health becomes 50%, 35% and then 20%. Add a "recovering" status that halves regeneration for a few minutes.

**Why:** death carries weight without destroying inventory, which suits mobile.

## 12. Creature model budgets

**Durango:** a 12 m raid boss was about 3,000 triangles, and a raptor about 1,700.

**Deadfront today:** Meshy creatures are 24,000 to 31,000 triangles.

**Change:** remesh creatures to the class budgets in `docs/art/durango-asset-benchmarks-and-tripo-prompts.md` before import. Add a triangle-count check to the creature validation sheet.

**Why:** phone frame rate. At this isometric distance the extra detail isn't visible.

## Suggested order

1. Items 1 and 2, fatigue scaling and breakdown: small, and they shape the whole session loop.
2. Items 3, 4 and 5, stagger, direction and taming odds: one combat pass that makes capture skilful.
3. Items 6 and 7, craft outcomes and material outputs: one crafting pass.
4. Item 12, model budgets: run in parallel on the art side.
5. Items 9, 10 and 11 as polish. Item 8 after the product decision.
