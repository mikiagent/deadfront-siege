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
