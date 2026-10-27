# DEADFRONT: complete UI and UX specification

**Purpose of this document.** Hand it to a designer, or to Claude Design, to produce the artistic vision for every screen in DEADFRONT. It states what the game is, what every screen must do, the real content each screen holds, the hard constraints of the engine, and exactly what to send back. It does not prescribe the final look. Where it states a current value, that value is what the game uses today and is open to change unless marked FIXED.

**Version:** 2026-10-17. Written from the game's code and data. Screenshots of the current state are in `docs/design/current-ui/`.

---

## 0. How to use this document

1. Read sections 1 to 5 once. They set the product, the art direction brief, and the rules that apply everywhere.
2. Design the foundations first (section 6): colour, type, spacing, shape language, icon style, motion.
3. Design the shared components (section 9) next. Every screen is built from them.
4. Design each screen in section 8, desktop first, then phone.
5. Return the deliverables listed in section 12.

If a rule here conflicts with a better idea, keep the rule and explain the idea in a note. The rules marked FIXED come from the engine or from the game's design and cannot change.

---

## 1. Product snapshot

**What it is.** DEADFRONT is a single-player survival, crafting, taming and base-building game. You are a survivor dropped onto a chain of dangerous islands. You gather materials, craft tools, hunt and tame dinosaurs and other prehistoric animals, build a camp, and sail to harder islands. The long goal is to forge a raid kit and defeat a volcano tyrant.

**Setting and tone.** Prehistoric animals and modern debris share the same islands because the world was torn open by a rift. The tone is practical and slightly wry survival, not horror and not cartoon. Text is short and concrete. The player is a competent ordinary person, not a hero.

**Core loop.** Gather, craft, hunt, tame, build, sail. Fatigue is the pacing limiter: it rises with work and with dangerous ground, and sleep is the only full reset. The UI must explain fatigue and never let it feel like a mystery.

**Platforms and judging.**

| Platform | Role | Notes |
|---|---|---|
| Desktop browser (Chrome), 1600 by 900 | The main judge. Every screen is approved here first. | Mouse and keyboard. Controller supported. Full screen supported. |
| Phone, portrait 390 by 844 | Must work, not the primary target. | Touch only. Safe areas apply. |
| Phone, landscape | Primary design intent for mobile play. | Touch. Landscape is the default orientation setting. |
| iOS app | Parked. Same UI as phone. | |

**Camera and world.** Orthographic, high three-quarter isometric, looking down on the survivor. The world is lit, textured 3D. Characters are about 1.8 m and read at roughly 80 pixels tall on desktop. The UI sits over the world, so every panel must stay readable over green grass, dark forest, sand, snow, lava glow and night.

**Audience.** Players who like Durango: Wild Lands, Last Day on Earth and similar mobile survival games, and who want clear information density rather than minimalism. Many play in short sessions of 10 to 20 minutes.

---

## 2. Design pillars

1. **Hierarchy before decoration.** One focus per moment: one target, one open wheel, one primary action. Everything else is quieter.
2. **The world is the menu.** Tap a thing, get the actions for that thing. Screens exist for managing, not for doing.
3. **Colour means things, white means actions.** Items, resources, creatures and gear are coloured. Commands, menus and gather glyphs are white or neutral. FIXED.
4. **Explain the number.** Every limiter (fatigue, capture odds, durability, level gap) has a place where the player can see why it is what it is.
5. **Hex is the language of actions.** Hexagons mean "you can do this now". Rectangles hold information.
6. **Works on a thumb.** Minimum target 44 px, main game actions 56 to 64 px, nothing hover-only.

---

## 3. Art direction brief

This is the part to explore. The values in section 6 are a working baseline, not a verdict.

**Reference for hierarchy only.** The game takes its information hierarchy from Durango: Wild Lands: stable bottom command rail, readable quest card, compact status bars, clear minimap, labels attached to the world, contextual hex wheels, and uniform dark hexes with white glyphs. Do not copy any of its art, icons, logo, type or layouts literally. DEADFRONT needs its own identity.

**Mood words.** Field notebook. Salvaged. Weathered. Practical. Warm in the camp, cold in the wild. Readable at a glance.

**Material cues to consider.** Cut paper and cardboard stencils, ink and wax pencil, canvas and rope, stamped metal tags, expedition maps, survey markers. These suggest a salvaged, field-kit feel that suits modern debris on a prehistoric shore.

**What it must not look like.** A generic sci-fi HUD, a fantasy RPG parchment UI, a glossy casual-mobile UI with candy gradients, or a realistic military simulator.

**Light and surface.** Panels are dark and slightly translucent so the world shows through. Edges are thin warm-grey lines. Selection is a single cool accent. Avoid heavy blur, large glows and drop shadows, because they are expensive on phones and in the engine.

**Biome mood.** Ten climates change the world's colour: savannah, temperate, tropical, tundra, desert, swamp, snowfield, blue tropical, volcanic, and the home grassland. The UI frame stays constant. Optional: a small per-climate accent used only on the minimap, atlas cards and island labels.

**Brand mark.** DEADFRONT with a "Durango Protocol" subtitle on the loading splash. The existing mark is a placeholder. A logotype and a simple emblem (hex-based) are in scope.

---

## 4. Terminology

| Term | Meaning |
|---|---|
| Survivor | The player character. |
| Bag | The player's inventory. 20 slots, stacked items. |
| Hex | A hexagonal button. Pointy top. |
| Radial, wheel | A set of hexes that appears around a world object. |
| Orders | The current objective, one of 28 in a fixed list, shown on the quest card. |
| Fatigue | The pacing meter. Called Tired, Weary, Exhausted at its stages. |
| Capture line | The 30 percent health mark below which an animal can be knocked over and tamed. |
| Pet, animal | A tamed animal. Unlimited owned, up to 3 out with you. |
| Atlas | The world map screen. |
| Harbour | The place where you sail between islands. |
| Station | A craft workstation: workbench, bonfire, kitchen items, mortar, smoker and others. |
| Pip | A small coloured dot on an item showing an attribute: yellow for a latent attribute, green for a rare extra. |
| SP | Skill points. |

---

## 5. Cross-cutting rules

### 5.1 Input model (FIXED)

All gameplay input goes through named actions. The design must show the right hint for the device in use.

| Device | How it works |
|---|---|
| Touch | Tap the world to move, interact or open a wheel. Tap hexes and buttons. Virtual joystick appears on touch devices. No hover. |
| Mouse | Click is tap. Hover may add a quiet highlight but never hides required information. |
| Keyboard | Movement and actions on keys, listed below. |
| Gamepad | Left stick moves. Buttons map to actions, listed below. Menus need a visible focus ring and must be fully operable with the D-pad and A and B. |

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD or arrows | Left stick |
| Interact, gather | E | A |
| Attack | F | X |
| Roll | Space | B |
| Sprint | Shift | Left stick click |
| Tackle | 1 | LB |
| Kick | 2 | RB |
| Tactic 3 and 4 | 3, 4 | Right trigger, left trigger |
| Craft | C | Y |
| Bag | I | Back |
| Map | M | Right stick click |
| Menu, pause | Esc | Start |
| Bandage | B | D-pad down |
| Hold or chase | H | D-pad up |
| Full screen | F11 | none |
| Placing: confirm, cancel, rotate | Enter, Esc, R | A, B, RB |

**Gamepad gap to design.** The four bottom hexes (Menu, Animals, Build, Skills) cannot take controller focus today. The designer should specify a focus model: either a focus ring that moves across the hex row with the D-pad, or direct shortcuts. Specify what the ring looks like on every focusable element.

### 5.2 Layout rules

- 8 px spacing grid. FIXED as the base unit; larger gaps are multiples.
- Panel corner radius 12 px for rectangles.
- Safe areas: on phones, every control stays inside the safe area insets.
- Desktop type: body 16, secondary 13, headings 24. Phone: body 14, secondary 12, headings 20. These are floors, not targets. Nothing below 12 px.
- Targets: 44 px minimum, 56 to 64 px for game actions, 64 px hexes in the nav row.
- No label may overlap another label, clip vertically, or shrink to fit. Long text is trimmed with an ellipsis at a stated width.
- Responsive anchors, not a phone canvas scaled up. Desktop uses the extra space for more columns and larger cells.

### 5.3 Colour semantics (FIXED)

| Meaning | Treatment |
|---|---|
| Things (items, resources, creatures, gear, food) | Full colour. |
| Actions (commands, gather, menus) | White or neutral glyphs on dark hexes. |
| Selected | One cool accent, currently teal. |
| Danger, invalid, bad outcome | Red, used sparingly. |
| Positive, ok, healthy | Green. |
| Warning, limited resource | Gold. |
| Never rely on colour alone | Always pair colour with an icon, a label or a shape. Red and green must also differ in lightness. |

### 5.4 Writing style

Short, concrete, sentence case for body, capitals for section labels. No exclamation marks. Numbers are exact. Say what to do, not what is wrong: "Needs an axe", not "You cannot do this."

---

## 6. Foundations (baseline, open to redesign)

### 6.1 Colour tokens in use today

| Token | Value | Use |
|---|---|---|
| Ink | #090A0C at 94 percent | Panel fill. |
| Ink solid | #0D0E10 at 97 percent | Opaque panels. |
| Divider | #8C8070 at 55 percent | Thin warm-grey borders and rules. |
| Teal | #33C7BD | Selection, primary actions, XP, capture line. |
| Teal dim | #1F6B6B | Selected fills. |
| Danger | #DB382E | Danger, health fill #D6362C. |
| Text | #F2F2EE | Primary text. |
| Meta | #C7C2B3 | Secondary text. |
| Energy blue | #3A86D6 | Energy bar. |
| Gold | #D9B34A | Hunger, bag fullness, grade S and A. |
| Green | #5FBF66 | Healthy, durability, positive. |
| Orange | #D98A3A | Attack stat. |
| Sky blue | #5FA6D6 | Defence stat, grade B. |
| Slot cell | #1A1C20 with #3A3D40 border | Item cells. |

Request: keep the semantics, propose the final values, and supply light-on-dark contrast numbers.

### 6.2 Typography

Current: the engine's default sans (Noto Sans style) plus symbol and emoji fallbacks. The designer should propose a heading face and a body face.

Constraints: must be a TrueType or OpenType font with a licence that allows embedding in a game (SIL Open Font Licence or similar). Must cover Latin with accents, numerals, and basic symbols. Prefer a condensed heading face with strong numerals, since bars and levels carry a lot of numbers. Provide the sizes for: screen title, panel title, body, secondary, caption, numeric large (levels, damage), numeric small (counts). Specify weights used and no more than three.

### 6.3 Shape language

- **Hex** (pointy top) for contextual and navigation actions. Currently 64 px with a 4 px caption below.
- **Rounded rectangles** (12 px) for panels and cards; 8 px for item cells.
- **Pills and chips** (6 px) for grades, tags and statuses.
- **Circles** for the minimap, respawn ring and step markers.
- Provide the 9-slice or vector spec for each.

### 6.4 Iconography

- **Item and resource icons** are full-colour pictures of the object. They are rendered from the game's 3D models, so the designer specifies the framing, lighting angle, padding, and background of the icon plate, not each drawing.
- **Action glyphs** are white, monochrome, stroke style, 24 px grid with 2 px stroke, rounded ends. About 40 are needed, listed in section 11.
- No text baked into any icon. No emoji in the shipped UI (emoji are a stopgap today).

### 6.5 Elevation, borders, effects

Panels use a 1 px divider border and a flat fill. No shadows and no blur by default. Allowed: a flat 2 px selected border, a 2 to 3 px accent edge on a card, subtle linear gradients on bars. If the design needs a glow or a texture, specify it as a pre-rendered image because live blur is costly.

### 6.6 Motion and feedback

The game has very little animation today, so the values below are a proposed baseline, not current behaviour.

- Panels open in 120 ms with a short slide or fade. Closing is 80 ms.
- Hex press: 60 ms scale to 0.96.
- Bars animate to new values in 180 ms.
- Toasts show for 2.5 s and fade in 150 ms.
- A gather wheel hex fills once per item gathered, in time with the actual gather timer.
- Provide the easing, durations and any looped animations (for example the pulsing outline of the current order). Everything must be skippable and must respect a reduced-motion setting.

---

## 7. Global structure and flow

```
Loading splash  ->  Character creation  ->  Choose first island  ->  Arrival card
      ->  Main play (HUD)  <->  Menu  <->  Bag | Craft | Map | Animals | Skills | Build
      ->  Sail (Harbour) to new island   |   Die -> Respawn card -> Main play
```

The HUD is always present during play. Every other screen is a layer over it: a sheet from the bottom-left (Menu, Build), a centred full panel (Bag, Craft, Animals, Skills, Atlas), or a wheel anchored on a world object.

---

## 8. Screen specifications

Each entry gives: purpose, how it opens, content, states, interactions, real strings, edge cases, and what the designer must produce. "Today" notes the current state so changes are clear.

### 8.1 Loading splash

- **Purpose.** Brand moment while the game streams in a large data pack (about 300 MB on web).
- **Content.** DEADFRONT mark, a progress bar, a build stamp in small text (for example `d7bf50295/60fb586ccd`).
- **States.** Loading, stalled (no progress for 10 s: show a retry hint), failed.
- **Design.** Mark, background, progress treatment, stalled and failed copy. The stamp must remain visible and small.

### 8.2 Character creation

- **Purpose.** Choose a background and name. One choice sets a starting skill at level 20.
- **Content.** Title `CREATE YOUR SURVIVOR`. Subtitle `Pick a background. It starts one skill at Lv. 20.` Eight cards, each with a name, a one-line story and the line `Starts: <Skill> Lv. 20`. A body choice, `Woman` or `Man`. A name field with placeholder `Survivor`. A primary button `ENTER THE RIFT`.
- **Backgrounds.** Soldier (Melee), Job Seeker (Defence), Office Worker (Construction), Technician (Weapon and tools), Flight Attendant (Tailoring), Student (Gathering), Homemaker (Cooking), Farmer (Farming).
- **States.** Nothing selected (button disabled), one selected, name empty, name too long.
- **Interactions.** Tap a card to select. The 3D survivor preview, if added, rotates and changes clothes per background.
- **Today.** Eight dark text-only cards. No imagery. Needs a portrait or emblem per background, a clear selected state, and a preview.
- **Design.** Card layout for desktop (4 by 2) and phone (2 by 4 scroll), selected state, body toggle, name field, button states.

### 8.3 Choose first island and arrival

- **Purpose.** Pick the home island's terrain, then confirm arrival.
- **Content.** Title `CHOOSE YOUR FIRST ISLAND`. Five options with a name and a subtitle: Meadow (Open grass), Forest (Dense wood), Rocky (Stone-rich), River (Fresh water), Coast (Wide shore). Then a card `YOU MADE IT` with the line `Your survivor is at the harbour. Tap the world to move and interact.` and a button `START EXPLORING`.
- **Design.** A bottom sheet of five option cards with an image or palette swatch each, and the arrival card.

### 8.4 Main HUD (always visible)

The densest screen. All elements below exist today.

| Element | Position (desktop) | Content |
|---|---|---|
| Vitals cluster | Top left | Level badge (a circle with the pioneer level), health bar with `current / max`, energy bar with `current / max`, a fatigue face with a label (RESTED, TIRED, WEARY, EXHAUSTED) and a percent bar. Tapping the fatigue face opens the fatigue panel (8.15). |
| Orders card | Top right, left of the minimap | Small caption `ORDERS 1/28`, the order title (for example `Gather 3 branches`), a one-line hint, progress `0 / 3`. A thin teal fill along its left edge shows progress. |
| Minimap | Top right | Circle, 154 px. Shows terrain, the player arrow, animals, stations. Tap opens the Atlas. Below it: coordinates `X 0 Y 0` and the clock `08:25 day`. |
| Island label | Above the minimap | Island name, or `Survivable 12 min` on a timed island. |
| Status badges | Under the minimap | Two-letter badges with a seconds timer, for example `WE` for Wet. |
| Nav hex row | Bottom left | Four hexes with captions: MENU, ANIMALS, BUILD, SKILLS. |
| Quick food hexes | Bottom left, above the nav row | Up to two hexes with a food icon and count. Tap eats one. Hidden when empty. |
| Hands hex | Bottom right | The held item or tool, with a short caption such as `HANDS` or `STONE WO...`. Tap swaps the tool. |
| Context hexes | Bottom right, above Hands | CLAIM (claim a plot), HARBOUR, WASH, DRINK, and others that appear when relevant. |
| XP bar | Bottom edge, full width | Thin. The text `Lv. 8 53.0%` centred. |
| Toasts | Top centre | Short notices such as `+1 Branch`, `Controller connected: Standard Gamepad Mapping`, and a one-time tip about the menu. |

- **States.** Normal, in combat (red frame at the screen edge, target plate, skill hexes), exhausted (face and label change), placing a building (world dims 15 to 20 percent), dead (hidden under the respawn card), mounted.
- **Interactions.** All elements are tappable except the clock. Keyboard and controller equivalents are in 5.1.
- **Today problems.** Small type on desktop, large empty corners, equal weight everywhere, debug glyphs sharing space with play controls.
- **Design.** One HUD for desktop, one for phone portrait, one for phone landscape. Specify the anchor of each element, its size, and how the cluster scales. Show the HUD in four moments: calm, gathering, combat with a target, and low health and exhausted.

### 8.5 Target plate and creature plates

- **Purpose.** Identify what you are fighting or taming and show its health.
- **Target plate.** Top centre, about 520 px wide. Name (for example `Compsognathus`), level `Lv. 15` in red, a portrait tile at the right with the species initial, a health bar with `current / max`, and status badges under the bar (two-letter, for example `GR` Groggy, `KN` Knockdown, `BL` Bleed). For a tamed pet the name adds `[A IV]`, its genetic grade.
- **Capture line.** On a tameable wild animal the health bar carries a teal line at 30 percent. Below it the animal can be knocked over and tamed.
- **Taming guide.** A panel under the vitals (top left) titled `TAMING` with three steps: `Wear it down`, `Knock it over`, `Feed it berry 0 / 3`. Done steps show a green tick, the current step a teal ring, later steps grey. Pen-only animals show `Take it to a pen`.
- **Creature plates.** A small plate over each nearby animal in the world: level and name, a thin health bar, and a `Tame 0/3` hint with a food icon when capturable. Only the target gets a full plate; others collapse to a short health tick.
- **Boss.** A boss with phases adds a line under the plate with the phase name, for example `Deafened roar`.
- **Design.** The target plate, the capture line, the taming guide, small plates, boss line, and the states: healthy, below capture line, knocked down, feeding with progress, tamed success, failed or escaped.

### 8.6 World labels

- **Purpose.** Name objects you can interact with, near the survivor.
- **Content.** A small dark chip with a coloured dot (green available, red needs a missing tool, grey depleted) and a name such as `Birch Tree`, `Workbench`, `Berry Bush`, `Basket`, `Cargo Warp`, `Harbour`. A depleted resource shows a regrow timer such as `3m 05s`.
- **Rules today.** Labels appear within 8 m, at most 12 at once, at most 2 of any one kind, nearest first, with a collision layout that keeps them apart.
- **Design.** The chip, dot states, a longest-name case, and how a crowd of labels thins out in a grove. Keep them legible over any ground colour.

### 8.7 Gather wheel

- **Purpose.** Pick what to take from a resource.
- **Content.** A centre tag with the resource name and level (for example `Birch Tree`, `Lv. 1`). Around it, up to five hexes. Each hex shows the item icon, the seconds it takes on top (`2.2s`), and the units left below (`15`). A side label shows `Bark Strip Lv. 1`. If blocked, the hex shows a small red badge and the label adds `needs axe`.
- **Interactions.** Tap a hex to start gathering. The hex outline fills once per item. Tap away to close.
- **Rules.** The wheel clamps to the screen. A label that cannot sit beside its hex moves above or below, never behind another hex.
- **Design.** The hex, the centre tag, the label styles, the blocked and depleted states, the progress sweep, and wheel layouts for 1, 2, 3, 4 and 5 options near a screen edge.

### 8.8 Station wheel and craft card

- **Purpose.** Craft at a station in two taps. Tap the station, then pick a recipe.
- **Stations.** Workbench, Crock pot, Meat dryer, Stone grill, Bonfire (action `CAUTERISE`), and more.
- **Content.** A wheel of recipe hexes around the station. A craft card shows the result name and level, `Lv 1 x1`, the ingredients with have and need counts, a time, and a Craft button. Missing ingredients show `Missing`. Locked recipes show `Locked` with the requirement.
- **Today.** Tiny labels and an uneven relationship between the object and the wheel.
- **Design.** Wheel, card, ingredient rows, locked and missing states, a craft in progress state with the hex over the survivor filling once per item.

### 8.9 Craft sheet

- **Purpose.** Browse every recipe, including hand recipes that work anywhere.
- **Content.** Title `Craft` or `Craft · Workbench`. Category list on the left, recipes in the middle, a `Details` panel on the right with an `INGREDIENTS` list and a result preview that shows the attribute pips and level the output would have. Helper lines: `Hand recipes craft anywhere. The hex over the survivor fills once per item.` and `Workbench in reach. Pick a recipe: the hex over it fills once per item.`
- **States.** No recipes in a category, locked recipe (kept in place, muted), missing ingredient, enough to craft, crafting.
- **Design.** Three-column desktop layout, phone stacked flow, recipe row, ingredient row, result preview with pips, and all the states.

### 8.10 Bag and character

- **Purpose.** Manage items and gear.
- **Content.** Title `CHARACTER`. Gear set tabs 1, 2, 3 (only set 1 is active today). Left: survivor name, background, `Lv. 8`, XP bar, stat rows Health, Energy, Gathering, and Bag `8 / 20` with a fullness bar. Centre: filter tabs All, Materials, Tools, Food, Gear, then a 5 by 4 grid of item cells. Each cell shows the icon, the name, and the count. Right: an Equipment grid of nine slots (Head, Body, Legs, Weapon, Tool, Ring, Ring, Food 1, Food 2), a selected item card, and action buttons.
- **Selected item card.** Name, level, a short description, attribute pips, durability bar `34 / 40`, and actions: Equip, Eat, Inspect, Feed pet, Place, Store, Lock, Drop, Food 1, Food 2. Only the valid ones show.
- **Item cell states.** Empty, filled, selected, locked (an `L` marker), unstable (a `U` marker), damaged, disabled when a storage is read-only.
- **Storage mode.** When a chest or a pet bag is open, a second grid appears under the bag with `Take all` and `Store`.
- **Real content.** 153 items in 41 categories. Longest names: `Log Shelter Kit (Planned)`, `Toxin Coating (3 Hits)`, `Makeshift Taming Pen`, `Flat Stone Grill Kit`. Stack counts up to 999.
- **Today.** 150 px cells with a tiny icon and no names (current build caps cells at 104 px and adds names). Equipment overflowed the right edge. Needs a stronger hierarchy and real item art.
- **Design.** Desktop three-column layout, phone single column with a swipe or tab between Bag, Equipment, Details, all cell states, the item card, storage mode.

### 8.11 Food inspector

- **Purpose.** Check a food before eating, because poison and bad taste are real hazards.
- **Content.** Title `Food`. Its attributes: freshness, poison risk, taste, energy value, buff, process count. Buttons `Eat`, `Feed pet`, `Close`.
- **Design.** The panel and a risk presentation that does not rely on colour alone.

### 8.12 Animals

- **Purpose.** Manage tamed animals.
- **Content.** Title `ANIMALS`, a count line `3 owned. 1 of 3 out with you.` A `WITH YOU` row of three slots. Each filled slot shows a portrait, name, level, a health bar and a Select button. An empty slot says `Empty slot. Equip an animal from the roster.` Below, a roster list on the left. Each row has a portrait badge, the name, `Level 100. With you` (or Down with a countdown, Hungry, At camp) and a grade chip. The selected animal on the right: a large portrait, name, grade chip, level, XP bar `18 / 1530`, hunger bar `3400 / 3400`, a primary button `Bring with you (0 of 3)` or `Send away`, stat bars for Health, Attack, Defense, Speed, and a Growth potential table with a grade chip, `+0 growth` and `EV 0` for Health, Melee Defense, Ranged Defense and Melee Attack.
- **Rules.** Unlimited owned, three out. A dead animal shows a ring with seconds left (about 60 s) and returns by itself. Animals have a pet food and a pet bag.
- **Grades.** S, A, B, C and plus or minus modifiers such as `A-` and `B+`.
- **Longest names.** `Stegosaurus`, `Compsognathus`.
- **Today.** Now rebuilt with a roster, slot cards and stat bars, using a hexagon with a letter as the portrait.
- **Design.** Portraits for 19 species, the grade chip colours, the stat bar style, empty, down, hungry and new-tame states, the phone stack.

### 8.13 Pet bag and pet actions

A pet with a bag opens a storage view of its bag over the Bag screen. Mounts can be mounted and dismounted from the world. Design the storage header (`Pet bag`), the mount prompt, and the dismount control.

### 8.14 Skills sheet

- **Purpose.** Spend skill points in twelve trees.
- **Trees.** Survival, Gathering, Butchering, Processing, Melee, Ranged, Defense, Weapon and tools, Tailoring, Construction, Cooking, Farming.
- **Content.** An overview list of trees with level, XP, and owned nodes, for example `Survival Lv. 8 44 / 80 XP owned 3`. Tapping a tree shows its node chain (a vertical dependency chain from a root), each node with a name, a level requirement, an SP cost, and a type (unlock or boost). Buttons `Unlock` and `Refund`, a header `<Tree> · Lv. 4 · 10 SP`, and `◀ All skills`.
- **States.** Owned, available, locked with a reason, selected.
- **Rules.** A skill cannot exceed the character level. Some skills need a research timer (planned). SP is limited, so the design must make cost and consequence clear.
- **Design.** Overview, tree view, node states, a node detail card, and a way to show the prerequisites without clutter.

### 8.15 Fatigue panel

- **Purpose.** Explain what is tiring you.
- **Content.** Title `What is tiring you`. A line such as `Island level 35, you are level 25: +60% fatigue.` and `Heat resistance is 1 short.` Up to four rows. Each row has a cause (Heat, Cold, Walking, Gathering, Fighting, Time awake), its share of recent fatigue as a bar and percent, and a one-line remedy such as `Eat a Cooling Meal or learn light heat clothing.` A Close button.
- **Opens.** By tapping the fatigue face in the HUD.
- **Design.** The panel, the row, the bar style, an empty state (`Nothing is tiring you right now.`), and a warning state when exhausted.

### 8.16 Build placement

- **Purpose.** Place buildings on claimed ground.
- **Flow.** Pick a kit from the Build sheet, drag a ghost onto the ground, then confirm or cancel. A Layout mode picks up and moves existing buildings.
- **Content.** The world dims. A thin grid shows. The footprint is teal when valid and red when invalid, with the reason as text such as `Can't place here: too far`. A compact rotate, check and X control sits near the ghost. A desktop hint shows `R rotate, Enter confirm, Esc cancel`.
- **Build sheet.** Title `Build`. A list of building kits in the bag, each as `Workbench 2x2 x1`. If none: `No building kits in the bag. Craft one at the workbench.` A button `Move buildings (layout mode)`.
- **Rules.** Only claimed ground is valid. Claiming a plot uses the CLAIM hex. Maximum placement reach is 8 m.
- **Design.** The overlay, valid and invalid footprints, the reason chip, the rotate, check and X control, the sheet, and the layout-mode state.

### 8.17 World Atlas

- **Purpose.** See islands, plan travel, understand levels and climates.
- **Content.** Title `WORLD ATLAS`. Region cards, each with the island name, a level band such as `Lv 35`, the climate, a short resource and animal summary, and travel state. A planning view of the current island's map with markers for you, wild animals, stations and the harbour, with `Zoom 1.0x`. A footer `You X 4 Y 11 Pioneer 5 T-stones 19`. Travel actions: `Harbour routes`, `Warp home`, `Return to camp`, and `Walking to X 4 Y 11`.
- **Islands.** 15 templates from the home grassland to the volcanic island at level 60. Climates: savannah, temperate, tropical, tundra, desert, swamp, snowfield, blue tropical, volcanic.
- **States.** Undiscovered, discovered, current, locked by Survival level (`Harbour - Survival 25`), expiring island (`Survivable 12 min`).
- **Design.** The atlas frame, the card, a climate accent per card, the map view with marker styles and a legend, and the locked and expiring states.

### 8.18 Menu, Controls and Pause

- **Menu.** A sheet that rises from the MENU hex. Title `Menu`, a line `Esc or Start opens this menu`. Rows: Bag (I), Craft (C), Map (M), Animals, Skills, then Save game, Full screen (F11), Controls, Debug info, Close.
- **Controls page.** A list of actions with their keyboard and gamepad inputs (section 5.1). A button `Back to menu`.
- **Pause overlay.** Esc or Start opens a simple panel `Paused` with `Save`, `Full screen` and `Resume`. Design this to match the Menu, or merge the two.
- **Settings (does not exist yet).** Needed: graphics quality (low, medium, high), frame rate (battery saver or quality), shadows, effects, language, voice language, orientation, UI size, volume sliders for effects, ambience, music and instruments, reduced motion, text size, colour-blind aids, controller layout, and a screenshot filter toggle.
- **Design.** Menu rows with key hints, the Controls page, a unified pause, and the full Settings screens for desktop and phone.

### 8.19 Death and respawn card

- **Purpose.** Calm, clear, never like a crash.
- **Content today.** Title `YOU DIED`. A cause line naming what downed you (for example `Stegosaurus`). A note: `Engaged dinosaurs retreat past their aggro ring. Your bag comes with you.` A button `Respawn at camp`. There is no countdown today.
- **Rules.** Respawn restores half health. A stacking penalty for repeated deaths in a row is proposed but not built, so leave room for one extra line on the card.
- **Design.** The overlay, the cause line, the note, the respawn button, and an optional second line for a penalty.

### 8.20 Notices, toasts and tooltips

- **Toasts.** Pickup (`+1 Branch`), system (`Controller connected: ...`), tip, warning (`Can't place here: ...`). Four types, each with an icon, a colour treatment and a duration.
- **Tooltips.** On desktop, hover on an item or hex shows name, level, attributes and one hint line. On touch, a long press does the same.
- **Confirm dialogs.** Needed for destructive actions: drop a stack, release an animal, refund a skill, overwrite a save.
- **Design.** All four toasts, the tooltip, and one confirm dialog.

---

## 9. Component library to design

For each, give the spec and every state: default, hover, pressed, focused (controller), selected, disabled, loading, error.

1. **Hex button.** Sizes 48, 56, 64, 72. Icon, optional caption, optional count badge, optional timer on top, optional red blocked badge, selected, and filling states.
2. **Primary, secondary, ghost, danger buttons.** Rectangular, 48 px high, 44 px minimum.
3. **Bars.** Health, energy, fatigue, XP, hunger, durability, bag fullness, stat comparison. Height 8, 10, 14 and 22.
4. **Chips.** Grade (S, A, B, C and modifiers), tag, status badge, key hint.
5. **Item cell.** 72 to 104 px desktop, 56 to 80 px phone. Icon, name, count, pips, lock, unstable and damaged markers.
6. **Pips.** Yellow latent attribute, green rare. Provide a shape variant for colour-blind use.
7. **List row.** 72 px with portrait badge, two text lines, trailing chip.
8. **Tabs and filter pills.**
9. **Panel, sheet, modal, card.**
10. **Stat row** with bar and number.
11. **Step tracker.** Done, current, upcoming.
12. **Radial hex group.** 1 to 5 hexes with a centre tag.
13. **Toast.**
14. **Tooltip.**
15. **Sliders, toggles, dropdowns** for Settings.
16. **Scrollbar** and **focus ring.**
17. **Portrait badge.** The animal and survivor stand-in until art exists.
18. **Respawn ring.**

---

## 10. Content and data limits (design for the worst case)

| Thing | Limit or example |
|---|---|
| Player name | No limit is enforced today. Design for 24 characters. Longest tested: `Stegosaurus Compsognathus`. |
| Level | 1 to 60 normal. The lab tests 101. Design three digits. |
| Item stack | Up to 999. |
| Bag | 20 slots. |
| Equipment | 9 slots. |
| Animals | Unlimited owned (design for 50), 3 out. |
| Animal stats | Up to 5 digits, for example HP 9281. |
| Item names | Up to about 26 characters. |
| Status effects | 18 kinds. Several can show at once on the target plate and under the minimap. |
| Timers | Up to three digits of seconds, and `3m 05s` style for regrowth. |
| Recipes | 71 today. Plan for several hundred. |
| Orders | 28, fixed order. |
| Skills | 12 trees, up to 60 levels, about 900 SP in total by the design estimate. |
| Islands | 15 templates. |
| Species | 19 today (Allosaurus, Ankylosaurus, Brachiosaurus, Coelophysis, Compsognathus, Deinonychus, Dilophosaurus, Gallimimus, Megaloceros, Protoceratops, Smilodon, Stegosaurus, Styracosaurus, Tarbosaurus, Triceratops, Tyrannosaurus, Utahraptor, Velociraptor, Zebraceratops). |
| Languages | Plan for English first, with 40 percent text growth for translation. |

**Item categories for icon plates.** food, building, blade material, meat, tool, cooked, wood, fibre, lashing, weapon, herb, stone, metal, fruit, bone, earth, burnable, log, ore, stalk, cloth, hide, seed, handle, medicine, tinder, buff food, crop, counter supply, preserved, water, treasure, bucket, flax, pet feed.

**Status effects.** Bleed, Deep Bleed, Venom, Fracture, Pinned, Deafened, Infected Wound, Groggy, Knockdown, Snared, Poisoned, Dizziness, Enraged, Wet, Full, Stomachache, Tastes Bad. Each needs a two-letter code today; the designer should propose a glyph for each.

**The 28 orders** run from `Gather 3 branches` through `Tame a Zebraceratops` and `Sail for Unstable Temperate` to `Forge the raid kit` and `Defeat the volcano tyrant`.

---

## 11. Icon and glyph inventory

**Action glyphs (white, monochrome).** Menu, Bag, Craft, Map, Animals, Skills, Build, Save, Full screen, Controls, Settings, Close, Back, Confirm (check), Cancel (X), Rotate, Gather, Attack, Tackle, Kick, Roll, Sprint, Net, Feed, Eat, Drink, Wash, Claim, Harbour, Sail, Home, Rest, Equip, Unequip, Drop, Lock, Unlock, Store, Take all, Inspect, Place, Move.

**Status glyphs.** One per status effect in section 10, 16 px, readable at a glance.

**Resource and item plates.** A plate style that sits behind full-colour item art: shape, border by category or rarity, how a stack count and pips attach.

**Map markers.** You, wild animal (passive and aggressive), tamed animal, station, building, harbour, warp, crater, discovered point of interest, route.

---

## 12. Deliverables to send back

1. **Art direction board.** Mood, palette, type, shape language, iconography, light and surface rules, in one image.
2. **Token file.** Colours, type scale, spacing, radii, borders, durations and easing as a table or JSON, with light-on-dark contrast ratios.
3. **Component sheet.** Every component in section 9 with all states, at desktop and phone sizes.
4. **Screens at 1600 by 900 and 390 by 844.** Every screen in section 8, with the listed states. For the HUD: calm, gathering, combat with a target, low health and exhausted.
5. **Flow diagram.** Boot to first minute of play, and the first tame.
6. **Icon set.** Every glyph in section 11 as SVG on a 24 px grid, 2 px stroke.
7. **Item and animal plate spec.** Framing and lighting for the icon renders, plus a placeholder portrait treatment.
8. **Gamepad focus spec.** The focus ring and the order of navigation for the HUD and for every screen.
9. **Motion spec.** Durations, easing, the list of animated moments.
10. **Notes.** Anything you changed from the rules here, and why.

**Formats that import cleanly.** SVG for glyphs and shapes, PNG for textures, a token table for values, and annotated screens with sizes and spacings in pixels. Fonts as .ttf or .otf with the licence.

---

## 13. Engine constraints (FIXED)

The game is built in Godot 4.7 and also exports to the web and iOS.

- UI is built from controls: panels with flat or 9-slice styles, labels, buttons, progress bars, and custom drawn shapes. Rectangles, rounded corners, borders and flat fills are cheap. Hexagons are drawn as polygons.
- No CSS. No live blur, backdrop filters, or complex shadows. If a glow or texture is wanted, deliver it as an image.
- Text is a font, not an image, so it can be translated and resized.
- Icons are SVG or PNG textures. Keep PNGs at 2x for desktop and mark the base size.
- Everything must run at 60 frames per second on a mid-range phone, so keep overdraw low and avoid many large translucent layers.
- The HUD is drawn live every frame from game state, so animated elements must be simple.
- The web build streams about 300 MB. New image assets should stay small: icon plates under 20 KB each, large backgrounds under 500 KB.

---

## 14. Current state and gaps (so you know what to fix)

| Area | State today | Biggest gap |
|---|---|---|
| HUD | Functional, small type, equal weight everywhere. | Hierarchy, desktop scale, a stronger bottom rail. |
| Gather and station wheels | Correct model, small labels. | A unified hex style and label rules. |
| Craft sheet | Functional. | Layout, result preview, locked states. |
| Bag | Rebuilt this week: names, stat rows, bars. | Real item art, a richer selected card, phone swipe flow. |
| Animals | Rebuilt this week. | Real portraits, grade styling, tame result feedback. |
| Taming | Capture line and steps added this week. | Odds, success and failure moments. |
| Skills | Text list and node chain. | A tree that reads as a tree. |
| Atlas | Region cards. | Map clarity, climate identity. |
| Build placement | Grid and ghost, washed out. | Dimming, local shadow, near-ghost controls. |
| Death | Card exists, never captured for review. | A designed calm state. |
| Menu | Rebuilt this week. | Merge with Pause. |
| Settings | Missing. | Everything in 8.18. |
| Character creation | Text-only cards. | Imagery, a preview. |
| Gamepad focus | Missing on HUD hexes. | The focus model in 5.1. |
| Item and animal art | Placeholder icons and a letter in a hex. | The icon plate system. |

---

## 15. Reference material

- Current screenshots: `docs/design/current-ui/` (taken from the game's screenshot lab with placeholder data).
- First pass mockups: https://claude.ai/artifact/YZfV9qu2EDxAxqN24RYsXz (private to the owner).
- Prior audit and rules: `UI-REDESIGN-AUDIT.md`, `GAUNTLET.md`, `docs/design/ui-pass-2026-10-17.md`.
- Controls table: `docs/controls.md`.
- Hierarchy references from another game exist in `docs/reference/` for the team only. Do not reproduce them.

---

## 16. Ready-to-paste prompt for Claude Design

> You are the art director and UI designer for DEADFRONT, a single-player prehistoric survival, crafting and taming game with an isometric 3D world, played on desktop browsers (1600 by 900 is the judge) and phones (390 by 844). The attached specification is the brief. Read it fully, then do this in order. (1) Produce one art direction board that commits to a single visual identity: a salvaged, weathered field-notebook feel with a hex-based action language, dark translucent panels, one cool selection accent, full-colour objects and white action glyphs. Do not copy the look of any existing game. (2) Produce the token table and the component sheet with every state. (3) Design every screen in section 8 at 1600 by 900 and 390 by 844, including the listed states and the real strings and worst-case content from section 10. (4) Design the gamepad focus model, the full Settings screens, and the icon set in section 11 as SVG on a 24 px grid with a 2 px stroke. Keep to the engine constraints in section 13. If you break a rule, say which and why. Return the deliverables listed in section 12.
