# Concept art and asset ledger

Status values: `DRAFT`, `APPROVED`, `GENERATED`, `REJECTED`, `INTEGRATED`.

Approval is version-specific. `Milan review anchor` records the authenticated message that approved the exact sheet. A blank approval anchor means no credit-bearing generation is authorized.

## Creatures

| Species | Concept version | Status | Milan review anchor | Meshy route/task | Credits | Model output | Rig status | Clip matrix |
|---|---|---|---|---|---:|---|---|---|
| Stegosaurus | `creatures/stegosaurus/concept-sheet-v01.png` | `DRAFT` | Seen by Milan; approval not received | Not started | 0 | None | Not started | See below |

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
