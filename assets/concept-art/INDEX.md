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
| Stegosaurus | `journal/creatures/stegosaurus/*-v01.png` | `APPROVED` | Authenticated iMessage reaction on `phonemsg-01M33F39RMBWMNS2KWJQNFT21C` at 2026-09-21 21:29 CDT | hero, silhouette, tail sweep, tracks, thagomizer, variants | Use the approved style as the journal bar. Track anatomy finalized from the planner's grounded Deltapodus brief: small crescent manus paired just ahead of a larger three-toed wedge pes; v01 is superseded by v02. |

### Stegosaurus journal component status

| Component | Source | Status | Proposed game path |
|---|---|---|---|
| Hero | `journal/creatures/stegosaurus/stegosaurus-journal-hero-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/hero.webp` |
| Silhouette | `journal/creatures/stegosaurus/stegosaurus-journal-silhouette-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/silhouette.webp` |
| Tail sweep | `journal/creatures/stegosaurus/stegosaurus-journal-tail-sweep-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/tail_sweep.webp` |
| Tracks/sign | `journal/creatures/stegosaurus/stegosaurus-journal-tracks-v02.png` | `APPROVED` | `game/assets/journal/creatures/stegosaurus/tracks.webp` |
| Thagomizer | `journal/creatures/stegosaurus/stegosaurus-journal-thagomizer-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/thagomizer.webp` |
| Variants | `journal/creatures/stegosaurus/stegosaurus-journal-variants-v01.png` | `APPROVED` style | `game/assets/journal/creatures/stegosaurus/variants.webp` |
