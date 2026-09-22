# DEADFRONT UI audit against Durango: Wild Lands

**Tag:** OPUS-SAFE  
**Evidence date:** 2026-09-21  
**Target:** desktop Chrome first; phone usable at 390 px  
**Production inspected:** `https://durango-like.vercel.app`, stamp `459f354cf/b143677ff6`

## Evidence and limits

This immediate handoff uses inspected DEADFRONT production/lab pixels and the repository's verified Durango: Wild Lands screenshot set under `docs/reference/`. The cloud browser is at **1200/1200 min (100%), capped til midnight**, so I could not add fresh current-web sources in this delivery. The reference images are visibly Durango: Wild Lands captures: branded HUD, named resources, hex interaction wheels, minimap, quest cards and bottom navigation. They are not generic mood images.

Reference map:

- `docs/reference/durango-base-reference.jpg` - main HUD, bottom nav, quest card, minimap, nearby labels.
- `durango-combat-reference.jpg` - combat HUD, action hexes, enemy identity/HP.
- `durango-gather-reference.webp`, `durango-tree-options-reference.webp` - resource labels and hex option hierarchy.
- `durango-crafting-reference.webp` - compact contextual crafting result.
- `durango-placing-reference.webp` - build overlay and confirm/cancel.
- `durango-taming-reference.jpg` - pet radial and contextual verbs.
- `durango-levelup-loot-reference.webp` - readable level/stat reward hierarchy.
- `durango-shore-reference.webp`, `durango-look-reference.webp` - quiet exploration HUD and visual density.

DEADFRONT pixels inspected:

- Desktop production soak capture `/tmp/ship-soak-desktop2/checkpoint-01.png`.
- `docs/orchestration/reports/m8c-hud.png`, `m8c-hud-hunt.png`, `m9a-creature-ui.png`, `m8e-craft-card.png`, `m8d-gather-radial.png`, `m8b-build-grid.png`, `m8d-placing.png`, `m8d-base.png`, plus the current UI implementation and UI-family lab.

Inventory/Animals/Growth were functionally verified in the shipped UI-family lab, but their newest full-screen pixels were not recaptured in this capped session. Treat those three visual judgments as provisional until the post-midnight capture pass. Do not fabricate detail from code alone.

## Ranked gaps, worst first

### 1. Main HUD and world labels - severe

**Observed DEADFRONT:** very small top-left bars; tiny labels floating over stations; bottom hexes are sparse and inconsistent in legibility; large dead corners; debugging/utility glyphs compete with play controls. The desktop screenshot has enough screen area, but information is still rendered at near-phone scale. Several labels visually overlap near Workbench/Cargo Warp. This is the strongest verified clipping/collision instance.

**Durango contrast:** `durango-base-reference.jpg` and `durango-look-reference.webp` use a stable bottom command rail, readable quest card, compact status bars, clear minimap, and labels attached to the world without stacking into each other. Important actions have consistent hex weight; minor information recedes.

**Direction:** rebuild responsive anchors at desktop scale. Create one bottom command rail with 48-56 px hex targets and consistent 20-24 px white action glyphs. Keep HP/energy/needs as a compact upper-left cluster with 13-15 px labels. Reserve upper-right for minimap/quest. Add world-label collision avoidance, max width, one-line ellipsis, and priority rules. Workbench and Cargo Warp cannot occupy the same label lane.

### 2. Creature plates / combat readability - severe

**Observed:** `m9a-creature-ui.png` shows many broad green bars with little identity, weak grouping and low information density; player/creature scale makes the plates dominate more than the dinosaurs. At gameplay distance the status hierarchy is hard to parse.

**Durango contrast:** `durango-combat-reference.jpg` names the target, level and HP in one strong identity strip while actions remain grouped at the lower right. Secondary enemies do not all receive equal visual weight.

**Direction:** one emphasized target plate with name, level, HP/status and optional tame threshold. Nearby non-target plates collapse to short HP ticks and reveal details on focus/tap. Tamed pets get HP plus thin XP underneath. Gathering UI must stay above plates. Remove dead-dino rings immediately.

### 3. Inventory / Character family - high, provisional newest capture

**Current shipped structure:** stats left, 5x4 bag + loadout, 3x3 equipment grid. Structure is correct, but the system must be checked for clipped item names, stat labels, stack counts and equipment-slot headers at both viewports.

**Durango contrast:** screenshot references use restrained dark translucent panels, strong category boundaries, colored object icons and white action controls. Information is dense but aligned.

**Direction:** keep the family architecture. Standardize 8 px base spacing, 44 px minimum rows, 64-72 px item cells desktop, 52-60 px phone. Full-color item/object icons; monochrome white action glyphs. Use 14-16 px body type, 12-13 px metadata, two-line item names with ellipsis after line two, never shrink below legibility. Put stats in aligned label/value rows.

### 4. Animals / Growth family - high, provisional newest capture

**Current shipped structure:** unlimited roster, three equipped, genetics and growth. Risks: card density, long species names/genetics labels, and unclear active-vs-owned hierarchy.

**Durango contrast:** `durango-taming-reference.jpg` uses a focused pet identity and immediate contextual verbs rather than equal-weight tiles.

**Direction:** left roster rail, center selected-animal portrait/stats, right growth/equipment. Three active slots stay pinned above the unlimited roster. Genetics tier only after tame. Long species names get one reserved identity line with ellipsis; stat labels never clip. Death cooldown is a circular overlay on that animal; HP and XP have distinct thickness.

### 5. Workbench / gathering radials - medium-high

**Observed:** the interaction model is now correct and real mouse clicks pass, but `m8d-gather-radial.png` and `m8e-craft-card.png` show tiny labels and uneven relationship between world object and wheel. The craft card is visually detached from the hex language.

**Durango contrast:** `durango-gather-reference.webp`, `durango-tree-options-reference.webp`, and `durango-crafting-reference.webp` keep a strong center/context anchor, uniform black hexes, white actions, colored resource objects and short quantities.

**Direction:** one reusable radial component. 64 px outer hexes desktop/phone; center tile identifies the source. White verb glyphs; colored item thumbnails; one short label plus quantity/level. Clamp to safe area and flip around the anchor. Two-step station interaction stays binding.

### 6. Build placement - medium

**Observed:** `m8b-build-grid.png` is washed out and the enormous shadow overwhelms the ghost; `m8d-placing.png` is clearer but confirm/cancel feel disconnected from the object. Grid and valid/invalid feedback are not one coherent visual system.

**Durango contrast:** `durango-placing-reference.webp` uses a darkened world, visible grid, central object ghost and a compact check/X wheel in reach of the object.

**Direction:** dim world 15-20%, keep grid thin, selected footprint teal/blue, invalid red only. Replace giant shadow with local contact shadow. Put rotate/check/X near the ghost and mirror keyboard labels subtly on desktop. Show cost before commit. Do not change build mechanics.

### 7. World Atlas - medium, provisional newest capture

**Direction:** map becomes a dark framed planning screen with region cards, level band, biome/resource/species summary and travel state. Maintain “World Atlas” branding. Use one selected color (teal), not competing saturated markers. Verify labels at zoom extremes and phone safe area.

### 8. Crafting sheet - medium, provisional newest capture

**Direction:** recipe categories left, selected recipe center, ingredient/result comparison right. Colored items, white actions. Locked requirements remain in place with muted styling instead of disappearing. Confirm button contains action + duration/cost and never clips.

### 9. Death / respawn - medium, missing decisive screenshot

No current decisive pixel capture was available. This is an audit gap, not a pass.

**Direction:** dedicated calm overlay with clear “downed/dead,” cause, respawn countdown/button and short note that engaged dinosaurs retreat. It must never resemble a crash. Capture and verify actual death/respawn before closing this screen.

### 10. Debug / testing UI - low priority in player build, high in testing range

Player production currently exposes tiny debug-like controls/labels. Hide them behind a debug flag. The separate `/showcase` testing range should own model, clip and diagnostics controls.

## System-wide style contract

- **Color = things; white = actions.** Item, resource, creature and gear art is colored. Action/menu/gather glyphs are white.
- Ink-black translucent panels (roughly 80-90% opacity), thin warm-gray dividers, restrained teal selected state, red only for danger/invalid.
- 8 px spacing grid. 12 px panel radius where rectangular; hex language for contextual actions.
- Desktop: 14-16 px body, 12-13 px metadata, 20-28 px headings. Phone must not drop below 12 px metadata / 14 px body.
- No baked text in icons. No label should overlap another, clip vertically, or shrink to compensate.
- Minimum target: 44 px; contextual/game action target: 56-64 px.
- Use responsive constraints and safe-area anchors, not a uniformly scaled phone canvas on desktop.
- Preserve Durango's hierarchy, not a literal copyrighted skin. DEADFRONT remains its own palette, icons and assets.

## Acceptance matrix

For every redesigned screen:

1. Capture 1600x900 desktop Chrome and 390x844 phone.
2. Test longest real strings: Stegosaurus, Compsognathus, “Ranged Defense,” “Obsidian Pickaxe,” large stack counts, level 100, three-digit timers.
3. Automated clipping probe plus pixel inspection: no overlapping world labels, cropped glyphs, vertical text clipping, or controls beyond safe area.
4. Full-color objects and white actions obey the semantic rule.
5. Real mouse and touch: modal open/close, radial two-step, drag/scroll, back/Escape.
6. Keep gameplay/save/economy behavior unchanged. This redesign is OPUS-SAFE presentation work.
7. Run import, tests, smoke, UI-family lab and desktop production soak; inspect screenshots rather than citing logs alone.

## Implementation order

1. Responsive token/theme layer and screenshot/clipping lab.
2. Main HUD + world-label collision (highest verified pain).
3. Target/creature plates.
4. Inventory/Character and Animals/Growth.
5. Shared radial + crafting family.
6. Build placement.
7. Atlas.
8. Death/respawn capture and redesign.
9. Remove production debug chrome; move diagnostics to `/showcase`.

## Audit closeout

The main gap is not feature count. DEADFRONT currently uses tiny phone-scale typography, low-detail default controls and equal-weight information on a desktop canvas. Durango's advantage is disciplined hierarchy: one focused target, one contextual wheel, one stable navigation rail and clear world labels. Fix those foundations before adding decorative framing.
