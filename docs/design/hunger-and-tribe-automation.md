# Hunger, tribe automation, and where the game stands

Design memo, 2026-10-29. Doc only: nothing here is built. It answers Milan's note of 2026-10-29:

> "hunger might need a rework (its very demanding and this game is more of a resource quality and skill
> building game, but resource quantity is not really as much of an issue except for hunger systems like
> that. Tribe members are cool but I'm trouble seeing what they could automate for me. Honestly it would
> be great if they automated building and crafting stations, like rather than me sitting there until its
> complete they could. But I want them to be able to do everything that requires a skill so I need to
> think about that."

Read against `claude/mmo-overhaul` at `2c446449`: `docs/current/survival-needs.md`, `docs/current/tribe.md`,
`game/scripts/items/digestion.gd`, `game/data/foods.json`, `game/data/tribe.json`,
`game/scripts/items/station_craft.gd`, `game/scripts/world/construction_site.gd`, vision §5, §10 and §12,
the Open Questions (A16, A17, T1-T15), the Durango wiki food page and the docs wiki Roadmap.
Guesses are marked `# ASSUMPTION`.

---

## Part 1. Hunger rework

### 1.1 What the build does today

- **The stomach is the digestion queue.** `Digestion.fullness()` sums, over every meal still digesting,
  the food's `fullness` × the share of its Energy not yet paid out. Almost every food digests over
  300 s. So **the stomach empties within about 5 minutes of the last bite, whatever you ate.**
- **Fullness values are small.** Berry 10, grilled meat 12, stew 7, mushroom 30, roast 50 (the biggest).
- **The bands punish emptiness hard** (A16, A17): empty ×2.0 exhaustion gain, hungry ×1.5, plus
  Starving (0.25 HP/s, stacking to 0.75 HP/s, floored at 1 HP).
- **Members are far gentler.** A tribe member loses 60 fullness per in-game day (720 s) and eats one
  item below 30 (T9). That is about one item every 12 minutes of play.
- **The real pace is hard to predict.** Digestion only pays Energy into room under the Energy ceiling, so how
  fast the stomach empties depends on how much stamina you are spending.
  `# ASSUMPTION: not measured in play; worth one logged session before tuning.`

Rough cost of staying at "normal" (≥ 40) by food type. This assumes digestion runs continuously, which
is the worst case:

| Eating only | Avg fullness one item gives over its life | Items to keep ≥ 40 | Items per hour |
|---|---|---|---|
| Roast (50) | 25 | 2 in flight, one every ~150 s | **~24** |
| Mushroom (30) | 15 | 3 in flight, one every ~100 s | ~36 |
| Berries (10) | 5 | 8 in flight, one every ~37 s | **~100** |

That is the "very demanding" feeling. Hunger has turned into a **quantity** chore, which is exactly
the axis Milan says this game is not about.

### 1.2 What the references actually do

- **Durango has no hunger death clock.** Its Fullness caps how much you can eat: it can reach 120 and
  decays at 0.1/s, so 100 → 0 takes about 17 minutes. The pressure in Durango is Energy (the work
  budget), and food matters through its **buffs** (two buff slots) and taste (wiki page 06).
- Our PRD says "no satiety meter" (`survival-needs.md`, A16). The current bands were a stand-in for one,
  and the stand-in became the harshest clock in the game.
- Vision §10 says food matters through **freshness, preservation, traits and buffs**, and that food
  quality matters to "expeditions, workers, dinosaur feed and children". None of that is about eating
  more often.

### 1.3 Options

| | Option | What changes | Good | Bad |
|---|---|---|---|---|
| A | **Slow drain only** | Fullness decays at a flat rate, decoupled from digestion. | One data change, tests barely move | Still a quantity chore, only rarer; quality still doesn't matter |
| B | **Satiety as a budget (Durango)** | Fullness is room in the stomach. Food fills it; it decays slowly; a full stomach refuses more. What you put in sets your buffs. | Faithful to the reference; makes cooking matter | On its own it gives no reason to eat at all |
| C | **Hunger as a buff source** | Being fed grants a "Well Fed" tier; the meal's buffs last *while you are fed*. Empty means no buffs and mild penalties. Starving only after long neglect. | Turns hunger from a stick into a carrot; quality food lasts longer | Needs the buff UI to read clearly |
| D | **Meal times** | 2-3 meals per in-game day get a bonus window, tied to waking or sleep. | Gives a rhythm; feels like "camp life" | A day is only 12 min of play, so the windows come too often unless tied to sleep |
| E | **Tribe kitchen / pantry** | Autofeed from a home pantry chest; a cook member prepares meals for everyone. | Folds hunger into automation (Part 2) | Needs Part 2 first |

### 1.4 Recommendation: B + C now, E with tribe automation

**"The stomach is a budget, and what fills it is your buff."**

1. **Decouple fullness from digestion.** Energy still digests over 300 s exactly as now; only the
   stomach number changes. Fullness becomes its own saved value: eating adds the food's `fullness`, and
   it decays at a flat rate.
   - Proposed rate: **100 → 0 over 40 min of play (2.5 per min)**. `# ASSUMPTION`
   - Target pace: **two or three eating moments per hour of play, each one a choice.**
2. **Rescale the fullness values so a real meal fills you.** `# ASSUMPTION` (all four values)
   - Raw fruit or berries: 6-10 (a snack).
   - Simple cooked food (grilled meat, skewer): 25-30.
   - Dishes with roles (stew, roast, seasoned roast): 45-60.
   - Feast-tier dishes, later: 80+.

   With these numbers one roast covers about 20 minutes and berries become filler.
3. **New bands.** These replace `rules.json fatigue.fullness_mult`. The thresholds and multipliers are an `# ASSUMPTION`.

   | State | Fullness | Exhaustion gain | Meal buffs | Other |
   |---|---|---|---|---|
   | Overfull | > 100 | ×1.05 | active | can't eat (the `full` gate) |
   | Well Fed | 70-100 | **×0.85** | active | small health regen bonus (+0.2 HP/s) |
   | Fed | 30-70 | ×1.0 | active | — |
   | Peckish | 10-30 | ×1.1 | active | autofeed fires here |
   | Empty | < 10 | ×1.3 | **off** | no regen bonus |
   | Starving | empty for 10 min | ×1.5 | off | slow DoT to 1 HP (owner rule kept) |

   Starving keeps Milan's "you should lose health" rule (A17), at a slower 0.1 HP/s
   (`# ASSUMPTION`), but only after **10 minutes on an empty stomach**, not the moment the ring empties.
   The existing rule that DoT never interrupts gathering or sleep still applies.
4. **Meal buffs last while you are fed.** Today a food buff runs on its own timer (for example 600 s).
   Instead, the `food_ability` / `food_survival` buff of your last real meal stays on until fullness
   drops below 10.
   - A bigger, better meal fills more, so it lasts longer.
   - Quality and level set the buff's **strength**, as spec 32 and the food sheet already do.
   - The HUD saturation ring (outer yellow ring) shows how long the buff has left, so it finally says
     something the player cares about.
   - A snack never replaces a dish's buff (it has none, and today's rule already keeps the older buff).

   This is the change that makes food about **quality, not quantity**.
5. **Autofeed keys off the stomach.** The quick-slot autofeed (`tick_autofeed`) fires at Peckish
   instead of at "Energy ≤ 50 %". A player who keeps a good dish in the quick slot never has to look at
   hunger.
6. **One rule for everyone.** Tribe members use the same stomach and bands, and so do tames later. A
   worker on a stew works better than a worker on berries (Part 2, §2.6).

### 1.5 What changes in data and code

| Where | Change |
|---|---|
| `game/data/world/rules.json` | New `hunger` block: `decay_per_min` 2.5, the band edges, `fatigue_mult` per band, `starving_after_s` 600, `well_fed_regen` 0.2. Retire `fatigue.fullness_mult`. |
| `game/data/foods.json` | Rescale `fullness` per food class (above). Add a `snack: true` flag for raw fruit, which carries no buff. |
| `game/data/statuses.json` | `starving`: 0.1 HP/s, a stack every 180 s up to 3. New `well_fed` buff chip. |
| `game/scripts/items/digestion.gd` | `fullness()` returns a stored value. `add_fullness(n)` is called from EatSession, and the value decays in `tick`. The save adds `fullness` and `empty_for_s`; an old save seeds it from today's formula once. |
| `game/scripts/items/food_effects.gd` / `BuffSlots` | A meal buff's expiry becomes "until fullness < 10" when its food has `duration_mode: "while_fed"`. That is the default for cooked dishes. |
| `game/scripts/ui/hud_stomach.gd` | The inner ring reads the stored fullness with the new band colours. The outer ring shows the meal buff's time left (fullness above 10, divided by the decay rate). |
| `game/scripts/player/player_sim.gd` | Starving starts after `starving_after_s` empty. Autofeed triggers at Peckish. |
| `game/data/tribe.json` | Drop `fullness_per_day` and use the shared hunger block. |
| Tests | Update `t_hudrules` stomach states, `t_needs`, `t_foodfx`, `t_tribe`. New `t_hunger`: decay rate, bands, while-fed buff expiry, starving delay, old-save seed. |

Size: one small package. The data-only half (step 1's rate and step 2's values) could ship first as a
hot fix if Milan wants relief tomorrow. `# ASSUMPTION: about half a day of build plus review.`

---

## Part 2. Tribe member automation

### 2.1 Where the friction is

- **Crafting holds the survivor.** `StationCraft` crouches her at the station, and walking past 2.8 m
  (`CANCEL_RANGE`) cancels the craft.
- **Building holds her too.** A construction site only advances while she hammers
  (`ConstructionSite.work`, driven by `build_ui`).
- **Only processing runs unattended.** Smoker, drying rack and furnace keep queues and catch up offline
  (`ProcessStation.advance`).
- **Today's times are short** (8-24 s per craft, 8-20 s per build). They will grow a lot: Durango-style
  pacing and timed skill research (48 h for Tailoring 49 → 50) are on the way. The wait only gets worse.
- **Members can only mine, chop, gather and fight**, with two skills (Gathering and Melee). They have
  nothing to do at a station or a site.

So Milan's instinct is right: **the waits are where a member earns their bed.**

### 2.2 The model: work orders at worksites

Every **station** and every **construction site** gets a work order slot. A member is assigned to it,
walks there and does the labour. The survivor is free the moment the order is set.

**Two ways to make an order**

1. **Hand-off (v1, the core ask).** The survivor opens the station exactly as today and picks the
   recipe and the exact material instances (the quality game stays in her hands). Instead of the crouch
   she presses **Assign** and picks a member.
   - The inputs go into the station's escrow, as construction sites already do.
   - The member walks over and crafts with the work animation and the recipe card above the station.
   - The output lands in the station's output tray or a linked chest.
   - Construction is the same: place a free blueprint plot, fill it (or "Fill automatically"), then
     Assign a builder.
2. **Standing order (v2).** Set a recipe, a quantity or "keep N in stock", and a **material policy**:
   lowest level first, highest level first, or only items with these tags. The worker fetches the
   inputs from linked chests itself. This is volume work: planks, rope, nails, smoked meat.

**What the worker's stats do**

| Factor | Effect | Rule it reuses |
|---|---|---|
| Skill level in the recipe's skill | Speed: craft time × (1 − 0.01 × level), at least 0.5 `# ASSUMPTION` | the same formula for player and worker |
| Skill level vs recipe difficulty | Success %, great success | the existing craft outcome curve, unchanged |
| Skill level | Output level cap, downrank below skill | the same rule the gathering jobs already use (max(skill, 5)) |
| Gear | Tool tier gate, speed, skill buffs | the seven slots members already have |
| Potential | XP gain only (×0.8 / 1.0 / 1.2 / 1.5) | T5, unchanged |
| Fatigue, fullness | Rests when exhausted; meal buffs speed up work | §2.6 |

Materials still set the item's level and traits. A worker cannot make a better item than its inputs
allow, only a faster or safer one.

**Safety rails**

- **Minimum success %.** Each order has one, default 80 % (`# ASSUMPTION`). A worker below it refuses
  and says why ("Joss: 62 % success, needs Woodworking 14"). This protects the "failed craft loses
  materials" rule from eating your best logs.
- **Tools.** A worker stops at 1 durability instead of breaking the tool (vision §12).
- **No phantom output.** No materials, no tool, no energy or no access means the job pauses, and the
  station shows why.
- **Offline.** Offline work catches up under the same limits, like `ProcessStation` already does,
  capped at 8 h (`# ASSUMPTION`).

### 2.3 "Everything that needs a skill": what that means

Milan wants members to do anything that needs a skill. The clean way is to give **members the
survivor's full skill set**: the same 12 trees, a level per skill, and XP from practice. Today
`TribeRecord` keeps only Gathering and Melee; that becomes a dictionary keyed by the same skill ids as
`game/data/skills/*.json`.

Then every skill-gated action becomes a job type:

| Skill family | Job | Exists as a player action today |
|---|---|---|
| Gathering, mining, logging | gather / mine / chop (built) | yes |
| Butchering | butcher a corpse brought to a butcher block | yes (corpse cut) |
| Cooking | cook at a fire or pot; keep the pantry stocked | yes |
| Processing (wood, stone, leather, metal) | process station loads and hand-off crafts | yes |
| Construction | build and repair at sites | yes |
| Tailoring, armour, weapons | station crafts | yes |
| Farming (later) | plant, tend, harvest | not built |
| Animal handling | feed and clean the pen | partly (pen) |
| Research | assist, see §2.4 | timer only |
| Combat | guard, follow, attack (built) | yes |

### 2.4 How it fits skill research and the cross-skill gear loop

**Skill research (proposal).** Research sets the **tribe's ceiling** for each skill. A member levels
by practice but cannot pass the highest cap the tribe has researched in that skill.
- The survivor's 48 h Tailoring research raises the cap for every tailor in the tribe, so research
  becomes the tribe's tech progress and matters more, not less.
- Members don't run research in v1. Later, a member with high Intelligence can be assigned as a
  **research assistant** at a study desk or Radio University and shorten the survivor's running research
  by a bounded amount (e.g. −10 % per assistant, at most 2). `# ASSUMPTION`

**Skill tree nodes (proposal).**
- **Knowledge nodes** (recipes, techniques, capture tiers) are **tribe-wide**: once bought, every
  member can use the recipe if their level allows. This matches vision §9: blueprints belong to a
  shared crafting world.
- **Stat nodes** (+speed, +yield) are **personal** and stay with whoever bought them. Members don't
  get SP trees in v1.

**The cross-skill gear loop gets a second customer.** Gear that buffs another skill (Spiky Armor →
Butchering) is today something the survivor crafts for herself. With workers it becomes **kit for your
staff**:
- the tailor wants the crafting gloves;
- the butcher wants Spiky Armor;
- the miner wants the best pick.

This is a direct reason to craft high-quality gear more than once, and a reason to care about the
quality of materials the survivor hand-picks. It is the strongest argument for automation in this
game.

### 2.5 What the survivor still does by hand

The point is to remove **waiting**, not **deciding**:

- **Hand-picking materials** for quality crafts and buildings. This is the core of the game.
- **The first craft of a new recipe** (proposal, "teach by doing"). The survivor makes a recipe once
  herself before it can be delegated. This keeps her own skills in use and makes new unlocks feel
  personal. `# ASSUMPTION: open question 6.`
- **Exploration, combat, taming, trading, and anything on an unstable island.** Workers stay home
  unless they are on follow.
- **Placing** plots and stations, and setting priorities.
- **Rare-trait odds.** A worker rolls rare finds and traits at most at the vision's bounded bonus
  (0-20 % relative), never more than the player. This avoids "automation is the only rational source
  of rare materials" (Traits math, open point 1).

### 2.6 How it ties back to hunger

- Workers eat from a **pantry** (any chest marked Pantry) when Peckish, preferring the best dish.
- A **meal buff makes work faster**. Cooked dishes carry a work-speed or skill buff for whoever eats
  them. `# ASSUMPTION: new buff stat "work_speed", +5-15 %.`
- A **Cook** order keeps the pantry at N dishes.

Together this is vision §10's "food quality matters to workers", and it gives the Cooking skill a
standing job.

### 2.7 UI

- **Station radial.** A fixed **Assign** hex in the Kingdom Rush layout, next to Craft, Package and
  Remove.
  - The craft card grows a second button: **Craft (you)** and **Assign…**.
  - The member picker lists each worker with their level in the recipe's skill, their success % for
    this recipe, and their time.
- **Construction menu.** An **Assign builder** button next to "Fill Automatically".
- **Tribe screen.** A **Work** tab showing every member's current order, its progress, and why a job
  is paused.
- **World.** A name plate plus a small job icon over each member, and the existing recipe card above
  the station.

### 2.8 Build order

| Package | Contents | Depends on |
|---|---|---|
| **TRIBE M2a: hand-off** | Assign one member to one craft (escrowed picks) or one construction site; walk, work clip, worker skill sets speed and success, XP to the member, minimum success %, refusals with reasons | station radial, construction menu |
| **TRIBE M2b: all skills** | Full skill dictionary on members, migration of Gathering/Melee, research cap, tribe-wide knowledge nodes | skill research package |
| **TRIBE M2c: standing orders + hauling** | Repeat/keep-in-stock, material policy, fetch from linked chests, deliver outputs, pantry, cook order | M2a |
| **TRIBE M2d: Monitoring Stand** | Priority board: members pick the next job by preference and capability (vision §12) | M2c |

M2a alone answers "rather than me sitting there until it's complete". `# ASSUMPTION: about 1 to 1.5 days of build plus review.`

### 2.9 Questions Milan said he needs to think about

| # | Question | Recommendation |
|---|---|---|
| 1 | Are recipes and skill-tree unlocks per person or tribe-wide? | Knowledge nodes tribe-wide; stat nodes and skill levels per person. |
| 2 | Do members get their own SP and skill trees? | Not in v1. Maybe later for "veterans", when switching characters arrives. |
| 3 | Can a member out-craft the survivor? | Same rules at the same skill level, so yes if they are more skilled. That is the point of a master smith. Rare odds stay bounded. |
| 4 | Who picks materials for a worker's craft? | Both: hand-picked for a hand-off, a policy for standing orders. |
| 5 | Can members research? | Not in v1. Research sets the tribe's ceiling; assistants later. |
| 6 | Must the survivor craft a recipe once before delegating it? | Yes ("teach by doing"). Cheap to drop if it feels like a chore. |
| 7 | How big can the tribe get? | Housing caps it today (2 + beds). Add a food cap once the pantry exists. Boats bring one recruit a day (T1), which may be too fast once members are this valuable. |
| 8 | Does work continue offline? | Yes, under the same limits, capped at 8 h. In multiplayer the server owns it. |
| 9 | What happens to a worker's job when the survivor sails away? | Home jobs keep running; members on follow come along and drop their order. |

---

## Part 3. Thoughts on the game as it stands

Candid, from reading the code, docs and reports, not from playing a build. `# ASSUMPTION` in that
sense throughout.

### 3.1 What is fun (keep investing)

- **Creature fights.** The Deinonychus template, compy swarm harassment, natures, packs led by Alphas,
  roll i-frames and "Dodged / Blocked / Missed" make fights readable and different per species. This is
  the most distinctive minute-to-minute play in the build.
- **Materials as individuals.** Instances with level and traits, carried into crafts, buildings and
  dishes. This is the game's identity and what makes it "resource quality, not quantity". Every system
  should feed it.
- **The look.** Coasts, weather tiers, lightning, fire with real fuel, the occlusion fade and the
  Durango camera. Screenshots read as a real game.
- **Taming with visible odds.** "Tame 64 %" before you throw is a good decision moment.

### 3.2 Friction (what makes it feel like work)

1. **The upkeep stack.** Hunger, exhaustion, thirst, dirty, wet, cold and heat, tool wear and negative
   perks each tax the player. Exhaustion alone multiplies about seven factors: the owner halving,
   stomach, statuses, shelter, level gap, climate and the per-source log. A player can't predict it.
   - Proposal: a target **upkeep budget**, no more than about 15 % of play time spent on survival
     chores, measured by the bot suite.
   - The hunger rework is the first big cut.
2. **Waiting at stations** (Part 2).
3. **Bag pressure.** Non-stacking instances plus backpacks as the only capacity source makes bag
   management heavy. Workers who haul to chests help. So do a "deposit all materials" button at a
   chest and grouping by def in the grid. The redesign is in progress; worth checking against this.
4. **Too many perks**, already being fixed (cap of 1-2 per item, lower grey rate). Keep that
   discipline everywhere: one clear trait beats three tiny ones.
5. **Systems that show but do nothing.** Many skill tree nodes are marked "not active yet", and
   Orders are placeholders until the Task screen lands. A node or task that does nothing teaches the
   player to ignore the screen.

### 3.3 Biggest risks to the playable loop

1. **Breadth over loop.** About 20 packages are in flight at once (bag, craft pop-out, radial,
   construction, tags, research, tree, tasks, market, two species, compy moveset and more). Each is
   good, but together they change every core screen in the same week. The roadmap's first goal is "a
   first hour that is fun", and nothing measures that hour yet: the bot metrics suite and the LOOPCHECK
   judge are both "later".
2. **Timers before automation.** Durango pacing (48 h research, long crafts) without workers or other
   things to do turns solo play into waiting. Land TRIBE M2a before or with skill research.
3. **Integration debt.** One integration branch, many parallel merges, and save-schema changes in
   several packages (bag, currency rename, skills research, tribe). Regressions will come from
   combinations no single package tested.
4. **Multiplayer authority is undecided** while client-side systems keep growing. Market, offline work
   and tribe automation all need a server rule eventually. Keeping logic in data and services (as the
   code mostly does) keeps the port cheap, but each new system should state its "server owns this" line.
5. **The art pipeline is a bottleneck.** 8 species are still stand-in boxes, Tripo credits are fixed,
   and the turnaround sheets depend on Milan. Don't let the roadmap assume art that isn't there.

### 3.4 Suggested order for the next week

Gameplay first and in roadmap order, with one measurement step added.

| Day | Do | Why |
|---|---|---|
| 1 | Land the open bug fixes (DoT, death delay, tent, second berry), the perk cap and the HUD follow-up. Ship the **hunger data hot fix** (§1.5: decay rate plus fullness values). | Fastest relief for what Milan feels now |
| 1-2 | **One measured session.** Milan plays 30 minutes; the build logs upkeep actions per hour, time in menus and time crouched at stations. | Gives the hunger and automation work a baseline instead of vibes |
| 2-3 | Land the bag redesign, the craft/build pop-out and the station radial. | M2a's UI hooks live here |
| 3 | **Hunger rework, full** (while-fed buffs, new bands, autofeed at Peckish). | Turns food into a quality system |
| 3-5 | **TRIBE M2a hand-off** (craft plus construction). | Milan's core ask |
| 5-6 | Skill research plus tree, with **M2b** (members get every skill, research sets the cap). | Research and workers designed together |
| 6-7 | Task screen with Milan's task sheet. Start the **bot metrics suite** (hour-one: level, upkeep %, Orders step). | Makes "is the first hour fun" testable |
| hold | New species past styracosaurus and pachycephalosaurus; market sell polish | Until the loop above feels good |

### 3.5 One-line summary

The game's identity is **quality materials and skilled people**. Hunger currently rewards quantity,
and the tribe can't touch skilled work. Fix both, measure the first hour, and slow the parallel
breadth for a week.
