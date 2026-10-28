# dsc — ICONS3: land the ICONS2 item renders on canon

ICONS2 (`claude/mmo-icons2`, 2026-10-21) rendered 32 missing and 33 weak item icons and fixed the
render script, but its gate never passed: `armor_scute` did not re-render byte-identically, 7 of the 65
ids were never repro-checked, and the `t_iconart.gd` change it needed was flagged out of scope. This
run brings the in-scope paths onto canon, re-proves all of it, and lists what canon still has no art for.

## What shipped

- **65 item renders** in `game/assets/icons/render/`: 32 that had no render at all and 33 redone. In
  `manifest.json` those are 32 new `items` entries and 33 changed sha256/bytes/rect; the other 100
  renders in the set are byte-identical to before (checked against the merge base `c9ec27c6`).
- **Their 32 `.png.import` files** (lossy WebP 0.8 + mipmaps, as `t_iconart` requires).
- **The builders that make them**: `tools/blender/items/resources.py` (17 raw materials),
  `camp.py` (15 kits, feeds, cages, dressing), plus `food.py` and `gear.py` for the flagged set
  (berry, mango, fish, grilled_meat, seasoned_roast, smoked_meat, burnt_food, raid_*, hides, ingots,
  cloth, clay, pillar, sign_kit, tent_kit, net II, snare, obsidian/black_iron, metal_shard).
- **`tools/render_icons.py`**: `crop_arm` / `close_gaps` (the arm pieces render as one arm with its
  parts touching instead of two floating arms), and the `REPLACE` register rewritten — 19 weak-art
  marks cleared, 14 kept with new text because `t_iconart` pins them.
- **`game/assets/icons/render/manifest.json`**: the 32 new entries and 33 new shas, everything canon
  already had preserved (every non-render field — `script`, `quality`, `replace` on all 133 canon
  entries — is unchanged), and `"missing"` regenerated from `game/data/items.json` minus the PNGs.
- **`game/tests/t_iconart.gd`**: the granted `_test_fallback` change (below).
- **`tools/blender/items/kit.py`**: `bevel()` now documents why the Bevel modifier must not be used on
  geometry with coplanar faces, with the measured evidence. No geometry change, so no re-render.

## Before / after (canon `23b37f29` -> this branch)

| | before | after |
|---|---|---|
| items.json ids | 240 | 240 |
| rendered ids | 132 | **164** |
| unrendered ids | 108 | **76** |
| unrendered with no symbol at all | 7 | 7 |
| manifest `missing` entries | 39 (stale: canon's list predated W2-DATA) | **76** (exactly the unrendered set) |
| PNGs in `render/` | 133 (incl. `_unknown`) | **165** |

The manifest `missing` list was the one thing that was actually wrong on canon: it had drifted from
`items.json`. It is now exact, which is what `t_iconart` checks (`missing` has no stale ids and every
unrendered item with no symbol is listed). `t_iconart` prints `pngs=165 missing=76 unrendered=76`.

## Determinism: armor_scute and the 7 unchecked ids

`armor_scute` no longer flips pixels. Four separate Blender processes each rendered it once and gave
the same bytes: `ICON armor_scute 53187 a5451fa408aed51b` / `REPRO armor_scute identical`, equal to the
committed PNG and to its manifest sha256 (`a5451fa4…`, 53187 B).

Root cause, re-measured this run (`.dsc/probe/bevel_probe.py`, `.dsc/probe/bevel_probe2.py`, 13
processes total): Blender's **Bevel modifier** evaluates to a different vertex/face order in different
processes (and moves coincident vertices by ~1e-9), so Cycles can hit a different face first on a
coplanar tie and flip a pixel by one LSB. It is stable *within* one process, `PYTHONHASHSEED=0` changes
nothing, and applying `bmesh.ops.bevel` by hand varies across processes too — so a seed, a fixed sample
count or an env var cannot fix it. The fix is geometric and is the one ICONS2 landed in
`resources.py armor_scute`: no bevel on its 12-gon prisms (`bev=0`) and the horn rim offset 0.01 in
from the bone's back face so no two faces are coplanar. `kit.bevel()` now carries that rule as a
docstring so the next builder does not reintroduce it; `.dsc/docs/render-determinism.md` has the full
write-up. Nothing in any builder reads the clock, an unseeded RNG or `os.urandom`; `kit.reset(id)`
seeds the per-item RNG from `zlib.crc32(id)` and `kit.stage()` pins Cycles to CPU, seed 0, 128 samples,
one thread, no denoiser, no adaptive sampling.

The 7 ids the ICONS2 gate never reached (it stopped at 58/65) were repro-checked together with
armor_scute in one Blender process:

```
REPRO armor_scute identical      REPRO steel_ingot identical
REPRO seasoned_roast identical   REPRO stone_knife identical
REPRO sign_kit identical         REPRO tent_kit identical
REPRO smoked_meat identical      REPRO travel_sleeves identical
REPRO PASS n=8
```

Cross-checking the whole landed set was attempted with `--verify all` (165 ids in one process); it was
stopped after 13 ids (all `identical`, no `DIFFERS`) because a full pass needs ~40 min of Blender on
this machine. The remaining 152 renders are byte-identical to canon's committed PNGs *by construction*
(the checkout only replaced the 65 + their imports), and 33 of them carry the branch's sha in the
manifest, which `t_iconart` checks against the pixels.

## The t_iconart.gd change

`_test_fallback` asserted "some unrendered item has a symbol to test the fallback with". Once every item
has a render that assertion can never hold, and the ICONS2 branch had already reverted it for exactly
that reason (the base test only passed because W2-DATA's new items happened to supply a subject).
Applied as granted: when no unrendered-with-symbol item exists the test prints
`[t_iconart] every item is rendered: symbol fallback has no subject, skipped`; when one does exist the
assertion still runs. Every other `_check` in the file is untouched. Proven both ways with throwaway
copies (deleted): disabling the subject search printed the skip line and PASSed; deliberately breaking
the symbol assertion (`path_for(sym_id) + "x"`) FAILed with `unrendered tin_ore resolves to its
ItemIcons symbol`. Today the real test still runs the assertion (tin_ore is its subject), so the change
is inert until the last symbol item is rendered.

## Items with no render (not rendered here)

76 of 240 canon items still have no render. 69 of them show a white symbol or their category fallback;
**7 have neither a symbol nor a fallback** and so fall through to the `_unknown` silhouette:
`advanced_backpack`, `basic_bag`, `large_pouch`, `small_pouch`, `specialized_storage_bag`, `strap`,
`woven_bag` (all BAGS/W2-GATHER ids added after ICONS2's manifest was written). They are why `missing`
must list them.

The 76, by family:

- **W2-DATA metals/tools/armour (59)**: `tin_ore`, `tin_ingot`, `moss`, `cactus_flower`, `forge_kit`,
  `anvil_kit`, `antivenom`, `antibiotic`, `capture_net_iii`, `capture_net_iv`, `capture_net_v`, and for
  each of flint / obsidian / copper / bronze / iron / steel: `_knife`, `_axe`, `_pick`, `_spear`,
  `_sword` (flint has no sword: flint_knife, flint_axe, flint_pick, flint_spear), plus `bone_knife`,
  `bone_axe`, `bone_pick`, `bone_spear`, and for each of leather / copper / bronze / iron / steel:
  `_helm`, `_cuirass`, `_bracers`, `_greaves`.
- **BAGS (6)**: `basic_bag`, `woven_bag`, `small_pouch`, `large_pouch`, `advanced_backpack`,
  `specialized_storage_bag`.
- **FOODFX / CRAFTFEEL / W2-GATHER (11)**: `crafters_meal`, `drip_coffee`, `dutch_coffee`, `tea`,
  `spring_water`, `fatigue_tonic`, `fine_plank`, `trimmed_plank`, `plank_shape`, `pillar_shape`, `strap`.

Not rendered here: 76 is far above the task's "< 10" threshold, and the shapes are new art direction
(5 armour slots x 5 metals, 6 tools x 5 metals, 6 bags, 5 food/drink). They need their own art package;
the cheapest near-term fix for the 7 silhouettes is symbol entries in `game/data/icons_manifest.json`,
which is outside this job's scope.

## Gates (lines seen)

- `verify_job.sh icons3 1` -> `VERIFY STAGE 1 PASS` (t_iconart PASS, no SCRIPT ERROR).
- `verify_job.sh icons3 2` -> `VERIFY HEADLESS-ONLY: visual lab deferred by owner` / `VERIFY STAGE 2 PASS`.
- `verify_job.sh icons3` (full) -> `VERIFY PASS`: t_iconart, t_items, t_data, t_uiicons (each exit 0 with
  its PASS line, no SCRIPT ERROR), `tools/smoke.sh --no-import` -> `SMOKE PASS`, and the scope check
  clean (base `23b37f29`; only `game/assets/icons/render/`, `tools/blender/items/`,
  `tools/render_icons.py`, `game/tests/t_iconart.gd` and `docs/orchestration/` changed).
- `--import` (headless): rc 0, no ERROR lines (the first stage-1 run failed only because the 32 new
  PNGs had no `.ctex` yet).
- Contact sheet `$TMPDIR/icons3/sheet65.png` (8 x 9, 256 px tiles, the UI ink background) of all 65
  changed ids, looked at: every tile present and readable, none blank, clipped or off-palette; light and
  palette match the untouched neighbours. Weakest at slot size: `forager_wraps` and
  `hide_bone_bracers` (thin one-arm slivers, as ICONS2 said; they keep their replace mark),
  `bark_strip` (reads a little like coiled rope), and the two cages whose animal is a green lump (the
  cage does the reading; CAGEICON owns that).

## Assumptions

None new. No balance numbers touched, no paid generation, no Godot windowed lab (headless-only banner
from the owner).

## What the integrator needs

- The work is in `game/assets/icons/render/` (65 PNGs, 32 `.import`, `manifest.json`),
  `tools/blender/items/{resources,camp,food,gear,kit}.py`, `tools/render_icons.py`,
  `game/tests/t_iconart.gd`, this report. Nothing outside the gate's scope changed.
- If the icon art is re-rendered later, run `--verify` of the ids you touched *in a fresh Blender
  process* and compare sha256 against the committed PNG: `--verify` in one process is the weaker test.
- The 7 symbol-less ids above want entries in `game/data/icons_manifest.json` (or renders) next.
- The two cages: `captured_animal`'s animal reads as a green lump at slot size; STATUS gives that to
  package CAGEICON (stacked on the ICONS2 branch, not on canon).
