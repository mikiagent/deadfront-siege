# Report: LABSPAWN (creature lab selector + compsognathus swarm AI), Claude

Branch `claude/mmo-labspawn`, cut from `origin/claude/mmo-overhaul` (d8e013fa). Not pushed.

## Try it
`Godot --path game -- --lab=creature_lab --species=compsognathus`
- Press **SPAWN** (gold, top left) to open the selector (or launch with `--spawn-open`). Pick a species (any species with a model), a
  count with − / + (1–6), a nature (tap to cycle: Random, Timid, Brave, …) and Alpha (on/off).
  **SPAWN** drops them as one pack 8 m in front of her; **CLEAR ALL** removes every wild animal.
- A compy only spots prey within about 4 m (perception 3.5), so walk up to the pack.
- The old keys still work: N enrages the nearest creature, F3 prints each move, and so do
  `--species=`, `--enrage`, `--ride=` (the ride fits a saddle, so mounting works) and `--seq=`.

## What shipped
- `LabSpawnPanel` (`game/scripts/dev/lab_spawn_panel.gd`): SheetChrome buttons and panel, all
  64 px tap targets, mouse or touch. `Spawner` gained `nature` and `force_alpha`.
- **Compsognathus = archetype `swarm`**, with its profile in
  `ai.json archetypes.swarm.tactics` (every number an ASSUMPTION):
  - **Surround** (`surround: true`): each packmate holds its own slot on a 3.5 m ring, evenly
    spaced by pack index. The ring turns 20°/s on the pack leader's fight clock.
  - **Dart in, scurry out:** sequences are a dart (charge into a bite) or a strafe then a dart.
    After each bite it runs straight back out (`backoff: "scurry"`, 0.6 s, facing the prey). Its
    feints (darting in without biting) count as repositioning, so it keeps feinting while the
    bite cools.
  - **Flee:** below 50% HP it flees for 3 s, then comes back. When a packmate dies the rest flee
    too.
  - **Bolder in numbers:** with 4+ in the pack, cooldowns ×0.6, more darts, shorter waits, and
    it flees only lower down. Alone: cooldowns ×1.8, more feints and back-offs, and it flees
    sooner.
  - **Opportunistic:** against prey under 40% HP, cooldowns ×0.6, more darts, almost no waiting.
  - **Enraged:** shorter cooldowns, more darts and strafes. Natures, `enrage_mult`, Timid
    `enrage_flee` and the alpha knobs all apply.
  - **Bites:** the basic bite fires only point blank. It keeps the beat between bites, the
    streak cap of 2 and the 15% share cap.
- **TacticalBrain, generalised:**
  - Situational modifier blocks (`enraged`, `pack_bold`, `alone`, `weak_prey`) are multiplied
    together through `_mod`.
  - New profile options: surround, scurry back-off, flee retreat mode, flee on a packmate's
    death, and feints counted as repositioning.
  - A leap whose clip is missing now keeps its stand-in loop playing.
- The pack attack gap (`_pack_cooldown_until`) now runs on the physics-step clock, not the wall
  clock, for every brain. That keeps the seeded censuses identical.
- **Missing compy clips for the art thread** (no credits spent): hop_back, leap_back, dodge_left,
  dodge_right, pounce, charge, bite_combo. It plays fine without them (strafes stand in for
  dodges, the run for the charge, and it scurries instead of leaping), but a short low **dart**
  (charge) clip and a **dodge_left/right** pair would sell it best.
- Docs: `docs/current/enemy-ai-template.md` (modifier blocks, swarm extras, the SPAWN selector);
  the class table in `docs/current/creatures-capture-taming.md` now marks swarm as built.

## Tests
- `t_labspawn` PASS:
  - lists 11 species with models;
  - SPAWN is 64 px and opens the selector;
  - through the panel's own buttons: 4 Timid compsognathus spawn as one pack, the alpha is
    member 0, all in front of her;
  - the count stops at 6, CLEAR ALL empties the field, and any species with a model can be
    spawned.
- `t_swarm` PASS, 3 identical runs:
  - a pack of 4 surrounds her (average largest neighbour gap 184°, against a 200° bar);
  - it darts and scurries out (39 darts, 45 back-outs in 30 s);
  - the plain-bite share is 0.025;
  - a hurt compy flees, and a packmate's death scatters the other two;
  - 19.5 darts/min each in a pack of four, against 8.0 for a lone compy.
- The other gates are in the hand-back.
