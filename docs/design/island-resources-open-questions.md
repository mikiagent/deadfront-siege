# Island maps and resources: open questions

**Status:** 2026-10-29, companion to [`island-resources.md`](island-resources.md). Three lists, kept apart on purpose:

- **A. Decisions for Milan:** all eight **decided 2026-10-29**: Milan chose "go with recommended", so the
  Recommendation column is now the rule.
- **B. Build-thread calls:** tuning and implementation choices the build thread makes with the default shown, marked
  `# ASSUMPTION` in data, per Milan's rule "no small tuning questions".
- **C. Unverified history:** Durango facts the handoff could not establish. They stay here until footage or game files
  settle them, and none of them blocks our design.

## A. Decisions for Milan (decided 2026-10-29: the recommendation in every row)

| # | Question | Options | Decision | Why it matters |
|---|---|---|---|---|
| **A1** | When an expedition island resets, what happens to buildings and stored goods left on it? | (1) Packed kits and harbour cargo survive to a home vault; placed buildings are lost but refund a share of materials. (2) Everything left is lost. (3) Everything is salvaged in full. | **(1)**, with a 50 % material refund (*ASSUMPTION*) | Decides whether expedition camps are worth building and whether "pack it or lose it" is the closing beat of a trip. Vision §2 leaves it open. |
| **A2** | Does an expedition island's clock run while the game is closed? | (1) Only while the game runs. (2) Real time, offline included. | **(1)** | With (2) a player can come back to a sunk camp they never saw sink. With (1) resets only happen while you could react. |
| **A3** | Dormant landmarks that you open with Gold for a short harvest window? | Yes / no | **Yes**, one per island from tier 30 | A Gold sink and a reason to revisit; world-design §6 already planned "closed craters" at 50. |
| **A4** | Home island material level: frozen at 1 (today), zone levels 1-10 (islands plan Q1), or growing toward 50-55 with a bigger home (vision §3)? | 1 / 1-10 / grows to 50-55 | **1-10 now, growth later** with home relocation | The docs disagree. It decides how much a player must leave home for quality. |
| **A5** | Should iron be reachable before level 60? Today iron ore grows only on the volcanic 60 island. | Keep at 60 / iron veins on tropical 40 and tundra 55 | **Veins at 40 and 55** | Otherwise every iron tool and armour piece is end-game only, and bronze is the practical ceiling for most of the game. |
| **A6** | Add the new materials the matrix proposes (feather, tea leaf, agave, lotus, ruby as treasure, iron ore), or keep to today's item list? | Approve all / pick / none | **Approve iron ore now**, the rest as content packages later | Each needs an item, a node family and a card. Iron fixes a ladder hole; the rest add flavour. |
| **A7** | Rare traits and landmark bonuses only from the player's own hands (tribe and stations get base odds and perk tier at most II)? | Yes / no | **Yes** | Keeps "active beats passive" true once tribe ASSIGN grows. |
| A8 | Landmarks per expedition island: 4-10 by size (Durango showed 2 / 13 found), instead of today's single crater? | Several / one | **Several** | The core of the proposal. Listed for completeness; it follows the handoff and spec 15. |

## B. Build-thread calls (defaults)

| # | Question | Default (*ASSUMPTION*) |
|---|---|---|
| B1 | Landmark node level offset | tier +5, cap 60 (world-design §3) |
| B2 | Landmark hand-harvest bonus | perk tier step +0.05, rare chance x1.5, inside the 1-2 perk cap |
| B3 | Landmark budgets | 4-6 / 6-8 / 8-10 by tier band; home 2-3; tutorial 6-8 authored |
| B4 | Ambient regrowth on expedition islands | x5 of today's 60-240 s |
| B5 | Partial regrowth on landmark nodes | 1 unit per 10 min if not emptied; emptied stays empty until reset |
| B6 | Warp holes (world-design §2): build them, and in which currency? | Later than M4; Gold, cheap; never Warp Gems |
| B7 | Discovery radius and reward | 18 m; 20-60 Gold by tier; first find per island also gives the fatigue drop |
| B8 | SCOUT from high ground | 120 m line of sight from a hill or plateau top; skill node adds range |
| B9 | Dormant window | 20 game-minutes |
| B10 | Reset warnings | 10 min and 60 s |
| B11 | Remove the 2 h `temperate_25` lifetime override | yes, use `lifetime_hours` |
| B12 | Guardian spawn trigger | first approach within 40 m, tier +3, alphas by the 8 % rule, none on the tutorial |

## C. Unverified history (from the handoff's §9, kept for research)

- Durango's island-template library: shapes, dimensions, terrain-generation parameters.
- Spawn densities, node spacing, material rarity odds and landmark-selection weights.
- Whether every listed biome-to-resource pairing (handoff §2) existed at the same time and in which patch.
- Exact crater activation rules, costs and outcomes; node regeneration and complete-depletion rules.
- Island reset durations by version, level and category.
- Which map markers or scanners showed resources before direct discovery.
- Resource quality, colour and trait distributions by island level and biome.
- How many landmarks an unstable island had (spec 15's screenshot shows "2 / 13" on a settled island; that may not
  carry over to unstable islands).

Sources named by the handoff: Durango Archive "Unstable Islands" (fan wiki), "Durango Wildlands Mastersheet"
(community compilation), BlueStacks "Getting Started in Durango" (guide), "Durango:0 Restoration Guide" (modern
reconstruction). All are secondary; check against footage before treating any as fact.
