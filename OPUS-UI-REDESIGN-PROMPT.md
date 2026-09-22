# OPUS-SAFE - DEADFRONT Durango-style UI redesign

You are implementing a presentation-only UI redesign for the Godot 4.7 project `mikiagent/deadfront-siege`. Work from current `origin/main`. Do not alter gameplay logic, save data, capture/taming rules, economy, spawn logic or combat formulas.

## Outcome

Make every player-facing DEADFRONT screen feel as deliberate, readable and coherent as Durango: Wild Lands while retaining DEADFRONT's own assets and identity. Desktop Chrome at 1600x900 is the native acceptance target; 390x844 must remain usable.

## Required reference files

Inspect these real Durango: Wild Lands screenshots before coding:

- `docs/reference/durango-base-reference.jpg` - main HUD/navigation/quest/minimap.
- `docs/reference/durango-combat-reference.jpg` - target identity and combat actions.
- `docs/reference/durango-gather-reference.webp` and `durango-tree-options-reference.webp` - resource labels and hex option wheel.
- `docs/reference/durango-crafting-reference.webp` - contextual craft result.
- `docs/reference/durango-placing-reference.webp` - placement overlay and check/X.
- `docs/reference/durango-taming-reference.jpg` - animal contextual actions.
- `docs/reference/durango-levelup-loot-reference.webp` - level/stat hierarchy.
- `docs/reference/durango-look-reference.webp`, `durango-shore-reference.webp` - quiet exploration density.

Inspect the current DEADFRONT screens and code. Do not infer visual quality from tests.

## Binding design system

- Color = things; white = actions. Item/resource/creature/gear icons are colored. Commands, menus, gathering and HUD action glyphs are monochrome white.
- Ink-black translucent panels, warm-gray dividers, teal selected state, red only for danger/invalid.
- 8 px spacing grid. Rectangular panels use restrained 12 px radius; contextual actions retain the hex language.
- Desktop typography: 20-28 px headings, 14-16 px body, 12-13 px metadata. Phone: never below 14 px body and 12 px metadata.
- 44 px minimum target; 56-64 px for primary game/context actions.
- Responsive anchors and constraints, not uniformly scaled phone UI on desktop.
- No baked labels in images. Never shrink text to hide clipping.
- Preserve the current two-step station interaction and all mechanics.

## Implement in this order

### 1. Shared responsive foundation

Create reusable UI tokens/styles for spacing, type sizes, panel colors, selected/danger states, target sizes and safe-area anchors. Add a deterministic UI screenshot/clipping lab. It must open every major screen at 1600x900 and 390x844 and test long strings and large counts.

### 2. Main HUD and world labels

Rebuild responsive anchors. Use one bottom command rail with consistent white action glyphs; compact upper-left survival bars; minimap/quest upper-right. Add world-label collision avoidance, priority, max width and ellipsis. Fix the verified Workbench/Cargo Warp label collision. Hide debug chrome outside debug mode.

### 3. Creature/target plates

One emphasized target plate: species, level, HP and statuses/tame threshold. Collapse non-target creatures to minimal bars. Tamed pets show HP and a thin XP bar. Gathering UI remains above plates. Dead creatures lose aggro rings immediately.

### 4. Inventory/Character and Animals/Growth

Keep the shipped structures: character stats + 5x4 bag + 3x3 equipment; unlimited animal roster + three active + growth/genetics. Improve hierarchy, spacing and typography. Pin three active slots. Use aligned stat rows. Long names use reserved lines plus ellipsis; no clipped headers, genetics labels, stack counts or timers. Death cooldown is circular on the animal.

### 5. Shared contextual radial and crafting

Build one reusable radial for gather, tame and station entry. Center identifies the source; outer 64 px hexes use white action glyphs or colored item thumbnails with one short label and quantity/level. Clamp/flip within safe area. Crafting uses categories left, selected recipe center, ingredients/result right; locked requirements remain visible.

### 6. Build placement

Dim the world lightly; thin grid; selected footprint teal/blue; invalid red only; local contact shadow instead of giant shadow. Put rotate/check/X near the ghost with subtle keyboard hints. Show cost before commit. Do not change placement rules.

### 7. World Atlas

Dark framed planning screen with region cards, level band, biome/resources/species summary and travel state. Preserve World Atlas branding. One teal selected state and readable zoom labels.

### 8. Death/respawn

Capture the current real screen first. Create a deliberate overlay with death state, cause, respawn countdown/action and concise note that engaged dinosaurs retreat. It must never look like a crash.

## Exact acceptance

- Actual screenshots at 1600x900 and 390x844 for every screen.
- Inspect pixels; do not report done from node trees or logs.
- Test strings: Stegosaurus, Compsognathus, Ranged Defense, Obsidian Pickaxe, large stack counts, level 100, three-digit timers.
- No overlapping world labels, vertical clipping, cropped icons, controls beyond safe areas or unreadably small metadata.
- Real Chrome mouse and touch interactions for modal open/close, station radial, scroll/drag and Escape/back.
- Run Godot import, full tests, `tools/smoke.sh`, `ui_family_lab`, relevant screenshot/clipping lab and desktop production soak.
- Verify production alias serves the exact `<commit>/<pack hash>` stamp.
- Return exact changed files, screenshots, gate results, commit, immutable deployment and alias stamp.

Do not copy Durango's proprietary art. Copy its information hierarchy, contextual hex grammar, spacing discipline and readability using DEADFRONT's original assets.
