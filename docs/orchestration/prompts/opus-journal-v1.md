# DEADFRONT Survivor's Journal v1

Filed by Claude Code on 2026-09-21 from a spec the owner pasted mid-session. Not started.
Handoff class: OPUS-SAFE (isolated, reversible, data-driven UI/content work). Escalate to Fable
only if implementation needs a change to core gameplay, save architecture or economy.

Prepared from the current game data at `db27b0b9`, Milan's standing requirements, `HANDOFF.md`,
and the approved Biome Gatherables design file. New world-lore language below is proposed canon
until Milan approves it.

## 1. Product job

The Survivor's Journal is the in-world wiki, but it should feel earned rather than like a
database dumped into a menu. It must answer five player questions fast:

1. What is this creature?
2. What can it do to me?
3. Where do I find it?
4. Is it worth taming, and what is it good at?
5. What have I personally learned about this individual?

The journal also gives DEADFRONT a memory layer: the player records a dangerous world, adding
sketches and corrections after encounters, building a practical survival manual.

### Binding existing systems it must preserve

- Species data remains JSON-driven under `game/data/creatures/`.
- Wild individual IVs stay hidden until tame. The journal may show a species tendency, never a
  wild creature's rolled grade.
- Individual tamed stats use the existing seven-stat system: Health, Melee Defense, Ranged
  Defense, Melee Attack, Ranged Attack, Accuracy, Speed. Grades remain D- through S+.
- Tames keep the identity and power of the wild animal. Do not describe them as nerfed pets.
- Starter-island creatures and gatherables remain level 1 even when the species normally belongs
  to a higher tier.
- Climate, island tier, combat verb, status, tame foods, capture tier, roles, bag slots and
  drops must come from data, not handwritten UI strings.
- Current capture gate is knocked out and below 30% HP. The older 10% note is superseded.
- Color remains for things. Journal tabs, buttons, filters and action icons stay white/monochrome.

## 2. Journal information architecture

### Entry points

Add `JOURNAL` to the Menu sheet, not the always-visible combat row. Also allow:

- `Open Journal Entry` from the creature inspect plate.
- `Species Notes` from a bonded animal's Growth screen.
- A small page-turn toast when new information is recorded. It must not stop movement or combat.

### Top-level sections

1. **Creatures** - extinct animals and later extant fauna.
2. **Flora** - the approved biome plants and harvest parts.
3. **Places** - climates, island rings, craters, ruins, hazards.
4. **Materials** - Stone -> Bone -> Flint -> Obsidian -> Copper -> Bronze -> Iron -> Steel.
5. **Survival Notes** - statuses, counters, taming, ecology, recipes learned through play.

Build Creatures first. Keep the shell reusable for the later sections.

### Creature index

Desktop: book spread, index left, selected entry right. Phone: one page at a time; index pushes
to entry; back returns to the prior scroll position.

Index controls: search by common/scientific name; filters All, Observed, Tameable, Owned,
Herbivore, Predator, climate; sort by Encounter order, Tier, Name, Climate. Locked species appear
as unlabeled charcoal silhouettes grouped by climate (no name, stats or ability before
discovery). Species with new notes get a folded-corner dot, not a bright badge.

## 3. Discovery progression

Each fact has its own unlock flag.

| Discovery event | What the page gains |
|---|---|
| Hear or find environmental evidence | Silhouette, climate hint, short evidence note; no dedicated print illustration |
| See within inspect range | Name, period/clade, scale sketch, habitat, temperament |
| Witness its signature attack | Combat verb, status, warning diagram |
| Defeat or butcher | Drop table and carcass notes |
| Knock down | Capture tier, knockdown warning, tame category |
| Successfully feed | Preferred and accepted foods used in that attempt |
| Tame | Full tame method, role ratings, bag capacity, individual Growth link |
| Travel with it / use ability | Utility note and role-specific margin annotation |
| Encounter a variant | Variant swatch and climate-specific note |

No event should unlock a guessed fact. Data-backed facts unlock; authored survivor observations
are tied to the same event.

## 4. Standard creature entry template

### Left page: identity and field observation

- Handwritten common/scientific name; taxonomy line (period, clade, diet).
- Dominant 3/4 field sketch, 55-65% of the page.
- Human silhouette scale bar with `recorded length` and `game scale` if they differ.
- Habitat strip: climate, island tier, island rings, activity window.
- Temperament stamp: Passive, Wary, Territorial, Pack Hunter, Apex.
- Two to four short survivor notes in first person.
- Behavior pair by diet: herbivores get an idle grazing scene plus defensive combat; carnivores
  get an idle stalking/resting scene plus feeding on a kill (no blood detail or gore).

### Right page: survival value

- **Species tendency**: seven compact horizontal bars (archetype tendencies, not IVs).
- **Combat card**: signature verb, applied status, telegraph, safe response, worst mistake.
- **Taming card**: tameable, capture tier, knockout/HP rule, preferred food, accepted food,
  feeds, timer, pen requirement.
- **Best at**: up to three honest roles (Combat, Cargo, Mount, Gather, Scout, Guard).
- **Weak at**: at least one tradeoff.
- **Drops**: base and rare drops, only after defeat/butchery unlock.
- **Owned specimen strip**: select a bonded animal to open the existing Animals/Growth screen.
- Bottom margin: source version and last balance revision, hidden outside debug builds.

### Writing rules

- Survivor voice is practical and terse. No encyclopedia paragraphs.
- One vivid observation, one danger, one use, one tradeoff per entry.
- Facts are ink; unconfirmed ideas are pencil with `?` and can be crossed out later.
- Behavior comes from ecology: feeding, herd/pack bonds, territory, time of day, weather, carcasses.
- Never hide a critical mechanic behind lore prose. Status, counter, tame gate and role have
  plain labels.
- Behavior art follows diet and ecology, not one repeated action formula. Feeding art stays
  field-notebook clean: no blood pools, torn flesh, exposed organs or dismemberment.

## 5. Entry order (content production)

Volume I: Compsognathus, Protoceratops, Coelophysis, Velociraptor, Deinonychus, Gallimimus,
Megaloceros. Volume II: Stegosaurus, Styracosaurus, Dilophosaurus, Smilodon, Ankylosaurus,
Utahraptor, Triceratops. Volume III: Allosaurus, Tarbosaurus, Tyrannosaurus rex, Brachiosaurus.
Volume IV: approved real fauna in biome order (home-island deer, boar, rabbit, turkey, bluegill;
savannah gazelle, ostrich, warthog; tropical tapir, macaw; cold-biome hare, ptarmigan, mammoth,
arctic fox; desert camel; swamp alligator, snapping turtle, catfish; blue-tropical crab, sea
turtle, oyster, reef fish; volcanic beetle, ash iguana). Shared species use one entry with
variant tabs; do not clone entries for recolors.

## 6. First full entry - Stegosaurus

Data header: Stegosauridae, Late Jurassic; recorded real length about 9 m; current game scale
`real_length_m: 18.0`, `height_meters: 6.4` (label it `game scale`, do not present 18 m as
paleontology); Tier 45 temperate; far shore of Temperate 35, working ring pairs and crater groups
on Temperate 45; archetype spiked tail; temperament wary herd defender; tameable, Capture IV;
roles combat and cargo; bag 100; preferred berries and herb leaves; accepted fibre stalk; six feed
progress, 45-second window, pen required; signature thagomizer tail sweep; status Deep Bleed;
base stats HP 8,500, Attack 380, Defense 300, Speed 400.

Display title: **STEGOSAURUS** - *"If it turns its head away from you, it has not lost interest."*

Left page copy: "Temperate highlands · Tier 45. A broad-backed herbivore with two staggered rows
of plates and four tail spikes. The head looks too small for the body. That is the trap. It does
not need to face you to decide a fight." Field notes: grazes at forest edges and open working
rings, adults gather near crater vegetation; a calm animal keeps its flank visible, an alarmed one
pivots its hips toward the threat; the plates are display and heat surfaces, watch the tail base;
a Stegosaurus that holds its ground can make a clearing safer. Signs in the environment: clipped
shrubs at waist height, snapped saplings, plate-scrape marks, paired drag cuts from the spikes.
Margin note: `Do not chase the head. The dangerous end is already behind you.`

Species tendency (0-5): Health 5, Melee Defense 4, Ranged Defense 3, Melee Attack 4, Ranged
Attack 0, Accuracy 2, Speed 2. Store explicitly; do not calculate from the four legacy stats.

Combat card - Thagomizer sweep: rear turn -> tail rises -> short stillness -> sweep. Hit applies
Deep Bleed, blocks natural regen, can stack. Safe response: leave the rear arc, move toward the
shoulder only after the tail commits. Worst mistake: circling behind it or crowding attackers
into one sweep. Counter: pressure dressing or cauterise at a bonfire. AI requirement: defend
space and herd mates, not chase forever; aggro ends at the visible radius.

Taming card - Capture IV, pen required: knock down and bring below 30% HP without killing;
45-second feed window from knockdown; berries and herb leaves full progress, fibre stalk half;
six feed progress; completion requires a pen. Tame value: combat (rear-arc control, Deep Bleed),
cargo (100 slots), proposed guard role; tradeoffs slow pursuit, no ranged, wide turning body,
attack needs room. Bond note: balance with upkeep, turning radius and cooldown, not stat cuts.

Proposed active commands (depth plan, not shipped facts): Hold Ground, Tail Warning, Sweep. The
page may list only actions that exist in gameplay; Hold Ground is the best first addition.

Entry unlock sequence: sighted (name, sketch, habitat, scale); signature witnessed (rear-turn
warning, Deep Bleed card); defeated/butchered (drops once the table is finalized); knocked down
(Capture IV, pen warning); fed (food notes); tamed (full roles, 100 slots, specimen link). Do not
ship a journal drop list until `game/data/butchering.json` has an explicit Stegosaurus record.

## 7. Art direction - survivor field notebook

Graphite construction sketch plus dry sepia ink with sparse watercolor or colored-pencil accents,
on warm weathered off-white fiber paper (creases and water rings only at page edges, never over
small text). Imperfect pressure line, visible searching lines, main contour 2-3x darker than
construction lines. Accurate silhouette and signature anatomy. Color budget 80% graphite/ink, 15%
muted species color, 5% danger annotation. Hand-drawn arrows, circles, scale ticks with one
margin symbol vocabulary. Danger marks in oxidized red pencil; tame/use marks in desaturated moss
green; one faint climate wash behind the feet.

Required illustration set per creature: hero 3/4 sketch (transparent), clean side silhouette,
signature-action diagram with ghosted poses and a red arc, idle behavior scene, signature
ecology scene by diet, head or weapon-anatomy detail, variant swatches.

Stegosaurus art brief: olive/sand hide, rust-charcoal plates, long raised tail, staggered
kite-shaped plates, four-spike thagomizer; hero pose rear 3/4 with head turned slightly toward the
viewer, all four feet planted; tiny survivor silhouette near the foreleg; combat scene against a
Deinonychus pack testing its flank; combat diagram with the three-beat tail sequence, red arc only
on the final pose. No generation-sheet labels, turntable boxes, Meshy marks or 3D rendering.

Production prompt skeleton: `Anatomically accurate [SPECIES] drawn by a skilled survivor in a
weathered field notebook, graphite underdrawing and dry sepia ink, broken pressure-sensitive
contour, sparse muted [PALETTE] colored-pencil accents, warm off-white paper, practical
hand-drawn arrows and scale marks, accurate silhouette and signature anatomy, 3/4
field-observation pose, no scenery, no photorealism, no 3D render, no glossy digital painting, no
printed labels, no UI, no watermark.` Generate without baked text; lay out text and arrows
in-engine.

## 8. Implementation plan

Files: `game/data/journal/creatures/<species>.json` (authored notes, tendency bars, art paths,
unlock rules), `game/data/journal/sections.json`, `game/scripts/journal/journal_state.gd`
(discovery flags and persistence), `game/scripts/journal/journal_catalog.gd` (merges journal
content with `CreatureDef` at read time), `game/scripts/ui/journal_screen.gd` +
`game/scenes/ui/journal_screen.tscn`, `game/assets/journal/creatures/<species>/`.

Do not duplicate tier, climate, stats, taming, roles, foods, bag slots or pipeline facts into
journal JSON; read them from `CreatureDef`. Journal JSON owns only authored prose, tendency
ratings, art references, discovery mapping and ecology notes.

Schema example:

```json
{
  "species_id": "stegosaurus",
  "order": 8,
  "diet": "herbivore",
  "behavior_scene_type": "defensive_combat",
  "temperament": "wary_herd_defender",
  "tendencies": {"health": 5, "melee_defense": 4, "ranged_defense": 3, "melee_attack": 4, "ranged_attack": 0, "accuracy": 2, "speed": 2},
  "art": {"hero": "res://assets/journal/creatures/stegosaurus/hero.webp", "silhouette": "...", "action": "...", "idle": "...", "signature_scene": "...", "detail": "..."},
  "field_notes": [
    {"id": "habitat", "unlock": "observed", "text": "Grazes at forest edges and open working rings."},
    {"id": "warning", "unlock": "signature_witnessed", "text": "When it turns its rear, the attack is beginning."},
    {"id": "herd", "unlock": "behavior_witnessed:herd_defense", "text": "Adults hold ground for the group."}
  ],
  "proposed_commands": ["hold_ground"]
}
```

Save state per species: seen, signature_witnessed, defeated, butchered, knocked_down, tamed,
foods_discovered[], behaviors_witnessed[], variants_seen[], new_note_ids[]. Version and migrate
through the existing save migration path.

Event hooks (signals from domain objects, not UI polling): inspect range -> observed; attack
resolves -> signature witnessed; status applied -> combat note; butcher -> drops; feed accepted
-> food discovery; tame success -> full block; ecology behavior signal -> herd/pack/feeding
notes; island arrival -> Places climate page.

UI: independent full-screen scene (not inside `hunt_hud.gd`); pause page input, not world
simulation, unless other full screens pause; desktop Chrome acceptance plus responsive phone;
44 px targets; Esc closes, arrows/page keys change pages, search focuses only on click; book
feel from layout, paper, page turn and marginalia, no heavy physics page-turn; text stays UI
text; sketches are transparent WebP/PNG; new-note toast never blocks combat input.

Handoff boundary: stop and return a FABLE-CRITICAL handoff instead of widening the patch if
any acceptance requirement needs a change to core save architecture, combat, taming, IV/stat
formulas, drops, crafting, progression, economy, shared creature lifecycle semantics, or a
migration that risks bonded animals, inventory, world state or progression.

Acceptance checks: (1) new save shows only locked silhouettes; (2) seeing Stegosaurus unlocks
identity/habitat only; (3) witnessing the sweep unlocks the Deep Bleed card and persists across
reload; (4) feeding a berry reveals berry only; (5) taming reveals roles and links the bonded
specimen; (6) wild grades hidden everywhere; (7) starter-island Stegosaurus shows level 1 while
the page says its normal tier/climate; (8) climate variants extend one page; (9) missing art
degrades to silhouette and data; (10) journal state survives save/load and older saves migrate;
(11) desktop and phone screenshots inspected; (12) deterministic `journal_lab` fires each
discovery event and asserts its unlock boundary.

## 9. Depth plan unlocked by the journal

Ecology first (feeding schedules, water visits, herd solidarity, alpha packs, scavengers
following carcasses, night hunting, territory and crater guarding). Biomes as survival stories
across the approved ten-climate chain. Lore frame: survivors call the unstable island network
**the Chain**; history is reconstructed from observations, trader notes, ruins and contradictions;
three deferred mysteries (why islands appear and sink, why animals from different periods
coexist, why some ruins predate current survivors); no magic labels unless the game commits.

Handoff rhythm: (1) journal shell + Stegosaurus + discovery state; (2) first-island seven entries
+ inspect hooks; (3) ecology signals + behavior unlocks; (4) ten Places pages; (5) Flora/material
sections; (6) status/counter pages; (7) ruin/trader lore only after canon approval.

## 10. Source-of-truth conflicts and blockers

- `stegosaurus.json` says `real_length_m: 18.0` while its `look` and the roster PRD say 9 m.
- Its JSON records an old Meshy pipeline and 48 credits; the journal must ignore pipeline
  provenance in player-facing text.
- No Stegosaurus entry in `butchering.json`; do not invent shipped drops.
- Creature data has four base stats; seven tendencies may display only if stored explicitly.
- Old schema quadruped notes conflict with the newer pipeline plan; do not copy pipeline language
  into UI.
