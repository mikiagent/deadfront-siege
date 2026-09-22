# DEADFRONT concept art library

This directory is the canonical, versioned source for DEADFRONT concept art and multi-view reference sheets. It lives outside `game/` so Godot does not import or package working art.

## Approval and credit rule

1. Create a numbered concept sheet and mark it `DRAFT` in `INDEX.md`.
2. Send that exact version to Milan for review.
3. Do not spend Meshy credits until Milan approves that exact sheet/version and the live Meshy web-subscription balance is verified.
4. Record the approval message anchor in `INDEX.md` and change the status to `APPROVED`.
5. Prepare clean, label-free generation views under the species `views/` directory only after approval.
6. If the concept changes after approval, create a new numbered version and repeat review. Approval never carries across versions.

Only existing web-subscription credits may be used. No Meshy API-credit workaround, top-up, plan upgrade, or new renewal is authorized.

## Directory convention

- `STYLE.md` - shared art direction, anatomy, scale, palette, and technical rules.
- `INDEX.md` - status, approval, Meshy task, spend, output, rig, and animation ledger.
- `creatures/<species>/concept-sheet-vNN.png` - complete review sheets.
- `creatures/<species>/views/` - approved clean side/front/top/rear-three-quarter inputs.
- `characters/`, `props/`, `nature/` - the same pattern for other asset families.

The production input folders under `game/assets/**/ref/` are staging areas, not the concept library. Copy only approved clean views there, and retain their `.gdignore` files.
