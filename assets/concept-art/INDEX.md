# Concept art and asset ledger

Status values: `DRAFT`, `APPROVED`, `GENERATED`, `REJECTED`, `INTEGRATED`.

Approval is version-specific. `Milan review anchor` records the authenticated message that approved the exact sheet. A blank approval anchor means no credit-bearing generation is authorized.

## Creatures

| Species | Concept version | Status | Milan review anchor | Meshy route/task | Credits | Model output | Rig status | Clip matrix |
|---|---|---|---|---|---:|---|---|---|
| Stegosaurus | `creatures/stegosaurus/concept-sheet-v01.png` | `DRAFT` | Seen by Milan; approval not received | Not started | 0 | None | Not started | See below |
| Deinonychus | `creatures/deinonychus/concept-sheet-v01.png` | `DRAFT` | - | Not started | 0 | None | Not started | Pending |
| Velociraptor | `creatures/velociraptor/concept-sheet-v01.png` | `DRAFT` | - | Not started | 0 | None | Not started | Pending |
| Utahraptor | `creatures/utahraptor/concept-sheet-v01.png` | `DRAFT` | - | Not started | 0 | None | Not started | Pending |
| Triceratops | `creatures/triceratops/concept-sheet-v01.png` (labelled review copy `concept-sheet-v01-review.png`; fix rounds 1, 2 and 3 replaced the draft in place, 2026-10-21) | `GENERATED` | Owner in the Claude Code session, 2026-10-21: "triceratops looks good" (sheet ad147d93) | Tripo multiview `P1-20260311` (texture, PBR, face_limit 20000), task `555e7332-ddd8-4583-b714-b98b6464aa24` (name `trike-v2-a`), success, 2026-10-21; balance 3155 before, 3105 after. Inputs: four clean views (front, left, back, right) made by Codex (dsc image tool, owner plan, 0 credits) with the approved sheet attached with its composite top view masked out; the left view was also attached to the other three; no sheet panel was cropped. Geometry QA passed (one island after weld, 0.7 % faces re-wound, three horns, solid frill, beak, four blunt feet, short tail), so the retry was not used. Not started; Tripo multiview only after approval. Sheet: ChatGPT web image generation on the owner's Plus plan, text-only prompts (no reference uploads). First draft: conversation `6ad860ec-6718-83ea-8edd-dfb73f4409a2`. Fix round 1: conversation `6ad8695b-5eb8-83ea-843f-a865ce7db0d2` (one generation + three edits), then local post-processing. Fix round 2 (paleo-art review: front brow horns, true top view, square stance): same conversation, one edit of the round-1 base image opened with ChatGPT's own image-editor Edit button (square standing pose in all views, front brow horns as end-on foreshortened cones, straight-down symmetric top view); local post-processing: ghost smears beside two horn tips removed, background set to 200,197,192, views re-laid on the 1672x941 canvas at one scale with the top view scaled x1.127 to the side view's length, the two near-side top-view foot nubs replaced by mirror images of the far-side nubs (both sides now show the same toes); round 1's top-view horn bend dropped. Fix round 3 (paleo-art review: front and top heads must match the side view, heavier hind legs, one width and foot-track rule): front view taken from one Codex CLI image edit (owner's plan, no credits; prompt plus the round-2 sheet as reference, only its front view used), scaled to the old front's height; locally its brow horns were redrawn as forward-pointing foreshortened cones (bases 112 px apart, outside the eyes, tips ~y 122), the face lifted to the side view's heights (eye 192, nose-horn tip ~195, beak tip ~296) and the hind legs added 10 px inside the fore track. Side view, local warps: hind leg and foot widened 1.22x (86 vs 74 px at y 400, foot 124 vs 108 px), shoulders lowered so the back peaks over the hips (x~687) 15 px above the shoulders. Top view rebuilt locally from sheet pixels: body narrowed 0.905x to the front's width (267 px), toe nubs removed (toes sit inside the barrel in the front view), frill re-projected from the front view as a crescent band x~245-390 with rim points on its back edge only, skull roof and a snout to the beak tip (x~107) with a short nasal horn, brow horns kept. Two Codex attempts at a new top view were rejected (long third horn; disc frill). Review copy: one 1.8 m human at 9 m beak to tail (`triceratops.json` `real_length_m` 9.0 since round 2, per the roster PRD) | 50 | `game/assets/creatures/triceratops/triceratops.glb` (in progress, TRIKE mesh stage) | Not started | Pending |

### Stegosaurus clip matrix

Allowed clip statuses: `preset-confirmed`, `preset-needs-cleanup`, `custom-T2M-approved`, `Blender-authored`, `fallback-rejected`, `missing`.

Do not infer coverage from Meshy's marketing count. Record the exact preset/action name and exported file only after inspecting it on the accepted rig.

| Clip | Status | Meshy preset/action | Export | Notes |
|---|---|---|---|---|
| idle | `missing` | - | - | Audit after Smart-Rig succeeds. |
| walk | `missing` | - | - | Audit foot contact and plate/tail deformation. |
| run | `missing` | - | - | Audit root movement and ground contact. |
| attack_primary | `missing` | - | - | Likely tail action; no assumption of preset coverage. |
| hit_react | `missing` | - | - | Hurt animation. |
| death | `missing` | - | - | Must settle without mesh stretch or plate clipping. |
| knockdown | `missing` | - | - | Must preserve the capture-state contract. |
| alert | `missing` | - | - | Species-readable defensive alert. |
| signature | `missing` | - | - | Thagomizer strike; Text to Motion only if no acceptable free preset exists and the approved cap covers it. |

## Characters

No entries yet.

## Props

No entries yet.

## Nature

No entries yet.

## Survivor's Journal art

Field-notebook style approval applies to the visual direction shown in the Stegosaurus v01 contact sheet: graphite construction, dry sepia ink, sparse muted olive/sand/rust-charcoal color, and oxidized-red danger marks. This approval is for journal sketch art only; it does not replace the realistic 3D concept direction.

| Species | Art set | Status | Milan review anchor | Components | Integration note |
|---|---|---|---|---|---|
| Stegosaurus | `journal/creatures/stegosaurus/*-v01.png` | `APPROVED` | Authenticated iMessage reaction on `phonemsg-01M33F39RMBWMNS2KWJQNFT21C` at 2026-09-21 21:29 CDT | hero, silhouette, tail sweep, tracks, thagomizer, variants | Use the approved style as the journal bar. Milan chose the single hind-print composition in authenticated iMessage at 2026-09-21 21:34 CDT ("One is better I think", replying to the A/B comparison; provider message ID was not present in the delegated evidence), replying to the A/B comparison. The page uses one large recessed three-toed pes print. The scientifically complete two-rail trackway is retained as unused reference only. |

### Stegosaurus journal component status

| Component | Source | Status | Proposed game path |
|---|---|---|---|
| Hero | `journal/creatures/stegosaurus/stegosaurus-journal-hero-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/hero.webp` |
| Silhouette | `journal/creatures/stegosaurus/stegosaurus-journal-silhouette-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/silhouette.webp` |
| Tail sweep | `journal/creatures/stegosaurus/stegosaurus-journal-tail-sweep-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/tail_sweep.webp` |
| Tracks/sign | `journal/creatures/stegosaurus/stegosaurus-journal-tracks-v04-single-pes.png` | `APPROVED` | `game/assets/journal/creatures/stegosaurus/tracks.webp` |
| Thagomizer | `journal/creatures/stegosaurus/stegosaurus-journal-thagomizer-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/thagomizer.webp` |
| Variants | `journal/creatures/stegosaurus/stegosaurus-journal-variants-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/variants.webp` |

### Stegosaurus journal page composition

SUPERSEDED: Milan removed footprint/sign art from journal pages at 2026-09-21 21:35 CDT. The single-print and two-rail assets remain unused research/reference history only; environmental evidence may unlock a short text note.


### Final Stegosaurus journal behavior art

The standard creature page uses two behavior scenes, not a track/sign inset: an idle field observation and a combat/defense scene. Carry this idle+combat pattern forward for every dinosaur journal entry.

| Scene | Final source | Status | Milan review | Proposed game path | Integration notes |
|---|---|---|---|---|---|
| Idle grazing | `journal/creatures/stegosaurus/stegosaurus-journal-idle-v01.png` | `APPROVED` | Approved as-is in authenticated iMessage context, 2026-09-21 21:37 CDT | `game/assets/journal/creatures/stegosaurus/idle.webp` | Calm grazing, planted feet, relaxed raised tail, no baked text. |
| Combat knockback | `journal/creatures/stegosaurus/stegosaurus-journal-combat-v06-fixed.png` | `APPROVED` | New v06 frame: "That's better" - authenticated iMessage, 2026-09-21 21:50 CDT; then surgical four-spike correction | `game/assets/journal/creatures/stegosaurus/combat.webp` | Low three-quarter depth view; thagomizer contacts Deinonychus and knocks it right; second hunter pauses; no gore; exactly four spikes. |

Superseded combat drafts v01-v05 are not integration candidates. The single pes print and two-rail trackway remain unused reference history only and must not appear in the page composition.
