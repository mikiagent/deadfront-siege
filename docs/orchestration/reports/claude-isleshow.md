# ISLESHOW: seeing the unstable-isle generator

Shipped (branch `claude/mmo-isleshow`):
- `game/scripts/dev/unstable_isle.gd` + `game/scenes/dev/unstable_isle.tscn`: `--lab=unstable_isle [--seed=N] [--template=<roster id>]`
  rolls an isle and lands the survivor at its dock, clock running; `--isleshow=<dir>` shoots 6 isles and a contact sheet, then quits.
- `tools/unstable_isle.command` (canon worktree, on-screen), HANDOFF.md entry, wiki page `docs/current/unstable-isles.md` (+ README row).
- `docs/orchestration/reports/isleshow/`: `contact_sheet.png`, per-isle top/ground JPGs (shrunk from the lab's PNGs), `summary.txt`.

What looks broken or bland in the shots (not fixed, no game code changed):
1. Black disks/blobs seen from above on tundra (1), volcanic (2 big) and swamp (inner island). Probably crater/pit tiles that render
   black from the top; not checked from the ground.
2. Landmarks repeat: desert has Cactus Garden x3; volcanic has every name twice; tundra and swamp too. Reads samey.
3. Savannah and tropical rolled only the minimum 4 landmarks.
4. Every landing is on the south coast (by design), so every arrival looks the same way.
5. Desert spiral: the land is about a third of its 415 m frame; the rest is shallows and islets.
6. Ground views: swamp is a flat reed field in murky water, tundra is a flat grey plain, volcanic is bare sand with rocks and has
   only 6 creatures. Savannah, tropical and desert read well.
7. Atolls (tropical, swamp): the dock is on the outer ring and landmarks sit on the inner island. t_unstable_isles asserts
   reachability for its own seeds; these six were not walked.
8. Lab only: the `[world] unstable isle ... rolled` log line prints the roll's climate before `--template` overrides it.
   Overview shots turn the climate fog off (from 600 m up it greys the whole isle).

Gates: t_unstable_isles PASS, t_islandgen PASS, run_all [tests] PASS, tools/smoke.sh --no-import SMOKE PASS, docs_wiki unittest OK (54).
Credits: none.
