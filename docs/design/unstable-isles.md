# Unstable isles: generated, short-life islands

Status: PROPOSED (built on `claude/mmo-unstable-opus`). Every number is `# ASSUMPTION` until Milan tunes it.
Source: Milan 2026-10-30 04:36, "Unstable islands as procedurally generated, short-term islands".
This is section 5.8 of `docs/design/island-resources.md` (on `claude/mmo-island-resources-doc`). It lives in its own file
until that doc lands, then folds in as 5.8.

## 1. What it is

The roster islands (savannah 15 to volcanic 60) are fixed places. Since M4 they reroll when their clock runs out (6 h, 12 h
or 24 h of play), but each one keeps its name, climate, level and harbour route.

An **unstable isle** is different: it is rolled from nothing, lives under an hour, and then sinks for good. It never comes
back. Its job is a short, risky trip that pays better than the roster, so a harbour visit always has a reason
to look at the board.

| | Roster island (M4) | Unstable isle (this section) |
|---|---|---|
| Where it comes from | A hand-tuned row in `world/islands.json` | Rolled on demand from a seed |
| Life | 6-24 h of play, then rerolls under the same name | Route open 20 min; once you land, 40 min; then it sinks and is gone |
| Building | Kits, blueprints, modular pieces | **Kits only** (packed prefabs). No blueprints, no walls or floors |
| Landmarks | 4-10, level +5 | Budget +2, level +8, plus one Rift Pool (driftglass), found only here |
| When it ends | Buildings refund 50 % to the home vault | Placed kits and their storage sink with it. You keep what you carry |

## 2. Rolling one (data: `world/rules.json` "unstable_isles")

A new isle is rolled when the survivor is at a harbour and none is on offer, at most once per **30 min of play**
(`offer_every_s` 1800). The first offer comes once the survivor reaches Survival 10 (the first sail gate).

From one seed, in this order:

1. **Level band.** The highest roster tier the survivor can sail to (`route_level` = tier - 5 <= Survival), then
   -5 to +5 around it in 5-level steps, clamped to 15-60. A higher-level isle is a stretch goal; a lower one is a quick, safe run.
2. **Climate.** One of the climates whose roster islands sit in that band (the roster row nearest the tier is the template:
   spawns, guardians, weather). Home climates are excluded.
3. **Shape family.** From `island_families.json` `roster_pick` (chains, bulky, round-with-peak, lobed, crescent, atoll,
   spiral), drawn on the seed's own stream.
4. **Size.** 260-340 m, smaller than a roster island (368-416 m), so a 40-minute trip can cross it.
5. **Name.** `"<Climate> Drift <roman numeral>"`, numbered by how many isles have been rolled.

The isle's id is `drift_<n>`. It is a normal `kind: "unstable"` island in every other way: unstable loot flags,
cargo warp, warp home strips unstable goods on foot, the harvest snapshot and regrowth rules from M4.

## 3. Reaching one

- It shows on the harbour list as a route with a countdown: **"Ash Drift II — sinks from the board in 18:40"**.
  It costs the normal sail fee in Warp Gems and needs the same Survival gate as its tier.
- If nobody sails within **20 min** (`offer_window_s` 1200), the route expires and a new one can roll after the
  cooldown.
- On landing, the island's own clock starts: **40 min of play** (`life_s` 2400). It runs on any island,
  never while the game is closed (same as M4). Warnings at 10 min and 60 s.
- Only one isle exists at a time (`max_live` 1).

## 4. Why go: richer or rarer

- **Landmarks:** the climate's normal budget +2, level offset +8 instead of +5 (capped at 60).
- **Rift Pool:** one extra landmark per isle, never on a roster island. Its Driftglass Node yields
  **driftglass**, a trade good that only grows on unstable isles. It sells high at the market, and it is the material of
  later warp-tier gear. That gear is a later content package, so for now it is a sell-only treasure.
- **Rare traits:** every node's rare-trait chance on an isle x1.25. This stacks with the M1 hand bonus (x1.5).
- Ambient nodes do not regrow there at all: you only get one pass at them in 40 min.

## 5. When it sinks

When the clock reaches 0:

- **The survivor is on it:** they are pulled to the home harbour, bag and all. Carried items keep their unstable flag,
  so the normal cargo rule still decides what survives the next warp. Tames on the leash come along.
- **Placed kits and their storage sink.** No refund. You get a warning at 10 min and 60 s to pack them up.
  Packed kits in the bag are carried items, so they come home.
- The isle's row, its landmarks found, its fog and its harvest state are deleted. The Library and map never list it again.
- **The survivor is elsewhere:** the isle sinks quietly; the next offer can roll after the cooldown.

## 6. Data and code

- `world/rules.json` `unstable_isles`: offer_every_s, offer_window_s, life_s, max_live, size_m, tier_spread,
  landmark_extra, level_offset, trait_mult, min_survival.
- `world/landmarks.json`: a `rift` type, and the `"generated"` climate row (the Rift Pool), used only by isles
  (`generated_only` rows).
- `World.drifts`: the live offer or isle row `{id, seed, tier, climate, template, family, size_m, offer_left, life_left, n}`, saved.
  `World.roll_drift()`, `World.tick_drifts(delta)`, `World.sink_drift()`. `def_of()` builds the def from the row.
- Building on an isle refuses blueprints and modular pieces ("Only packed kits stand on an unstable isle").

## 7. Test gate (`game/tests/t_unstable_isles.gd`)

- 12 seeds roll and build: each is valid (a harbour, landmarks inside the budget + 2, every landmark reachable by TilePath,
  the Rift Pool placed), and its climate and tier are inside the band.
- The route expires when not sailed; the cooldown holds.
- Running the life clock out while on the isle sinks it: the survivor is at the home harbour with the bag intact, the isle's row and
  state are gone, the harbour list no longer has it.
- Driftglass grows only on isles: no roster climate yields it, and every isle has a source.
- A save round trip keeps the offer and the clock.

## 8. Open questions (defaults chosen, Milan can change)

1. Should the sink pull keep carried unstable goods (chosen: yes, flag kept), or strip them like a warp home?
2. Should more than one isle be live at once later (chosen: one)?
3. Should driftglass have a recipe now (chosen: sell-only until warp-tier gear exists)?
