# Zebraceratops: rig integrated, on the home island, published

Date: 2026-09-21. Agent: Claude Code (art pipeline + integration, since Codex is out of usage).

## What shipped

- `game/assets/creatures/zebraceratops/`: Codex's rig (skeleton transplant v3 from the Quaternius
  Triceratops donor, 9 clips under `anim/`, `sheet.png`, textures, `asset_manifest.json`). Only
  `work/zebraceratops_i2m_v1.glb`, `work/rig_manifest.json` and `work/generation_ledger.json` are
  committed from `work/`; `rigged.blend` and the raw texture dump stay local like the other species.
- `game/data/creatures/zebraceratops.json`: new stat block. Pipeline block carries the Meshy task
  ids, clip lengths and the rig manifest.
- `game/data/butchering.json`: `zebraceratops` table, same yield family as Protoceratops with one
  less meat and a charcoal hide tint.
- `game/data/world/islands.json`: herd of 3 in the home island gathering ring (30-60 m from camp)
  and a herd of 3 in the savannah_15 gathering ring (the PRD's first unstable island).
- Published to Vercel with `tools/publish_pck.sh`; testers pick it up on next sign-in.

## Validation

- `tools/smoke.sh`: SMOKE PASS.
- `--lab=home_lab` headless: `[creature] zebraceratops spawned pack=2` x3, all 9 clips remap
  with `missing=0`, `spawn_rejected=0`. The only warnings are the pre-existing
  AnimationNodeBlendSpace1D deprecation notice every species hits.
- `sheet.png` reviewed: horizontal spine, four planted feet, frill, brow and nose horns, stripes.

## Assumptions (PRD is silent)

- `# ASSUMPTION:` Stats. The PRD gives only bag 50, capture tier I, wild level ~13, "slow mount,
  light combat". Scaled down from Protoceratops (tier 20, hp 980 / atk 45 / def 110 / speed 420):
  tier 13, hp 720, attack 36, defense 80, speed 400, bag_slots 50.
- `# ASSUMPTION:` Size. real_length_m 2.4, height_meters 1.0 (compact, a bit larger than
  Protoceratops, per the art direction and the BlueStacks reference).
- `# ASSUMPTION:` Home island spawn. The PRD puts the first Zebraceratops on the first unstable
  island; the user asked for it on the starting island, so it is on both.
- `period` is "Durango original (fictional)"; the roster PRD's "real species only" rule is
  overridden by the systems PRD (§11.4) and the explicit request.

## Credits

Meshy: 48 spent by Codex against a 96 cap (two references + one multi-image mesh). This task spent 0.

## For the next agent

- Cursor: `game/data/skills/trees.json` capture tier I text still names "Coelophysis,
  Protoceratops"; Zebraceratops is capture_tier 1 in data, so the label should mention it.
- The nine other species' GLBs in the working tree are re-rigged (rig revision 3) but not yet
  committed; they went out in this pack because the export reads the working tree.
