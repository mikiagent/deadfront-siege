# dsc report: annotate superseded docs (2026-10-27)

Agent: dsc. Task: `annotate superseded DEADFRONT docs`. Meshy credits spent: 0.

## Shipped

Banner/note-only edits, no body content rewritten apart from the one bullet the task named:

- `AGENTS.md` — the mobile-first bullet now reads: **Desktop Chrome (1600x900, real mouse, 16:9) is the
  primary acceptance target and ship gate; mobile/touch stays a supported secondary target.** The
  InputMap / 64 px / safe-area / `--touch` sentences are unchanged.
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` — `> SUPERSEDED 2026-10-27:` banner: real-species-only
  policy dropped (Zebraceratops canonical), Meshy text-to-3D/UI-API pipeline replaced by web-subscription
  generations, Tripo and donor-skeleton transplants, triangle numbers replaced by the measured budgets doc.
- `docs/orchestration/plan.md` — `> HISTORICAL RECORD, written 2026-09-17. Read-only as of 2026-10-27.`
  banner: M8/M9/M10 numbering diverges from the executed M8a-e / M9a-b / M10 prompt series; mobile-first
  and no-web-export were reversed by `HANDOFF.md`; executed history is `docs/playtests/` and git log.
- `docs/engine-decision.md` — `> SUPERSEDED IN PART 2026-10-27:` banner: Godot 4.7 decision stands; the
  Meshy text-to-3D/API import specifics and export tooling notes are historical; `HANDOFF.md` is the
  current pipeline authority.
- `assets/concept-art/STYLE.md` — inline `*(superseded 2026-10-27 …)*` markers on the PBR line and the
  10k-20k/20k-35k triangle line, plus `## Budgets update (2026-10-27)`: 1,200-1,800 tris under 2 m,
  1,800-2,500 at 3-6 m, 2,500-4,000 at 8 m+, 25-45 bones, 512² textures, matcap-first lighting; current
  creatures measure 24k-31k tris and owe remeshing; source `docs/art/durango-asset-benchmarks-and-tripo-prompts.md`.
- `assets/concept-art/INDEX.md` — `## Ledger status (2026-10-27)` before `## Creatures`: ledger lists 4
  DRAFT species against ~19 shipped, Stegosaurus's shipped asset is a 48-credit transplant under
  `game/assets/creatures/stegosaurus/`, rows are historical until backfilled, no clip inference.

## Verified

`bash .dsc/verify_docs.sh` prints `verify PASS`. It asserts the AGENTS.md phrasing, a banner in each of the
three docs, both art-doc sections and the budget numbers, and that `HANDOFF.md`, `GAUNTLET.md`,
`docs/design/**` and `game/**` are unchanged.

## What the next agent needs

- The ledger is still unbackfilled. `game/data/creatures/*.json` `pipeline` blocks are the reliable record
  (`route`, `credits_spent`, `donor_rig`, `clips`); backfilling INDEX.md from them is its own task.
- `docs/art/durango-asset-benchmarks-and-tripo-prompts.md` still states "Real species only, per
  `docs/prd/dinosaur-roster-and-3d-pipeline.md`", which the new roster banner contradicts. Left alone
  because that file was outside this task's edit list.
- `.dsc/` is gitignored, so the verify script had to be copied locally to run; the repo copy lives at
  `.dsc/verify_docs.sh` outside git.
