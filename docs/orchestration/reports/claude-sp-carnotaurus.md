# SP-CARNOTAURUS: a new species, the Carnotaurus

Branch `claude/mmo-sp-carnotaurus`. It was cut from `origin/claude/mmo-overhaul` and canon has since been merged in again (aba7ecc3). It is pushed but not merged to canon.

Owner brief: "Fast bull-like predator: horn ram that knocks the target back, sprint charge with a sharp turn, snap bite." Owner sheets: `carnotaurus_owner_sheet_1_open` (the regular skin) and `carnotaurus_owner_sheet_2` (the alpha skin). Both are in `game/assets/creatures/carnotaurus/ref/`.

## Credits
**Tripo: 100**, from two P1 multiview generations (the one allowed retry was used). Meshy 0, no paid images. The Codex CLI drew one image, which was free.
- Balance was 2505 before and 2305 after. Other species agents spent on the same account at the same time, so the difference is not all mine.
- `a5576e4e-e1a4-45f4-979c-b5b1841dd3e3` (50): the front view plus the sheet's mid-stride side view. It came back with **four hind legs**, two forward and two back, so it was rejected.
- `489df448-650c-4508-92c2-4c7b03d3c12d` (50, accepted). Inputs:
  - the front view from the sheet;
  - a Codex neutral-stance side view (feet side by side), plus its mirror.
- The Tripo V3 API was called directly with the key in `~/.tripo/config.json`. The key was never printed.

## Model and rig (rebuild: `tools/gait/build_carnotaurus.sh`)
- `tools/transplant_rig.py` with the Velociraptor donor. `--leg` places the joints by hand, read off the mesh: hip in the thigh, the hock, the **heel**, and the toe tip.
  - The ankle has to be at the heel. With the ankle at the ball of the foot, the heel pad stayed on the metatarsus and sank 0.1 m into the floor whenever the hock bent.
- Jaw: `add_jaw.py --open --x-side --pivot 0.071 0.36 --split -5 --blend 0.01`.
  - **New `--x-side` flag.** This jaw points level, and the glTF round-trip flipped its local X. Without the flag, `--open` opened the mouth to 46 deg instead of closing it, and positive key angles closed it. The flag rolls the Jaw so +X opens, like the other species. Other species are unchanged (the flag is off by default).
- Size: 12.9 m long and 5.74 m tall. That is 8 m real x 1.6, `real_length_m` 16 (# ASSUMPTION, Open Questions CA2).
- Alpha skin: `carnotaurus_alpha_albedo.jpg`, baked by `tools/gait/make_carno_alpha_skin.py` from the regular map.
  - It is rust and black, with black mottling heavier on the back. Shot: `sp-carnotaurus/alpha_skin_blender.png`.
  - There is no horn mask. The Tripo UVs share texture space between a horn island and a shin island, so painting the horns black also blackened a shin patch.

## Clips (16)
| clip | source |
|---|---|
| walk, run, charge, strafe_left/right, walk_back | `make_gait.py` + `tools/gait/carnotaurus.json`. The charge is a head-low horn sprint with the arms tucked. There is no toe roll or swing curl: on this long heel-to-toe foot both pushed the toes or heel under the floor. |
| attack_primary | **snap bite**: coils, darts down to survivor height, snaps shut at 0.42, shakes its head |
| attack_heavy | **horn ram**: rears back bellowing, then scrapes a hind foot twice like a bull while the head drops to aim the horns (this is the telegraph, with a ground ring). It steps in and drives horns-first (hit at 0.72), then hooks its head up. |
| charge_turn | **sharp turn**: plants and crouches, then hops round to its left with the body banked and the tail flung wide, and lands squashed. Airborne 0.2-0.6. |
| alert | roar: rears up, then thrusts the head forward with the jaws wide and shaking |
| idle, hit_react, feed | `make_carno_moves.py`. The donor's idle and hit_react held the raptor's feet 0.86 m off this rig's prints, so I replaced them. |
| knockdown, death | the transplant's donor collapse |
| sleep | the velociraptor's, moved across with `transfer_clips.py` |

The attacks, alert, idle, hit_react and feed come from the new `tools/gait/make_carno_moves.py`:
- the feet stay IK-planted on their prints;
- a pose that takes a hip out of reach lowers the body;
- a heel roll pivots about the claw tips.

`ground_clip.py` gained a `--fps` option. At 30 fps its samples fell between this clip's 24 fps keys and missed a toe dip; the default is unchanged.

## Moves and AI (new archetype `horned_hunter`, a TacticalBrain tactics block in ai.json)
- **Opening**: it stands off on a 13 m ring, roars (display), then charges. Roar-then-charge and the plain charge are about 3/4 of picks; strafe-then-charge is the rest.
- **Sprint charge with a sharp turn** (`charge_straight`):
  - The line is locked and it runs head-low at 1.7x speed.
  - A hit (x1.6) hooks her 60 deg off the line and throws her 3.5 m (`charge_toss_deg`, new). Straight ahead she stood in its path and stopped it dead.
  - It runs on 9 m past her, then **hops round to its left** (`charge_turn`, new) and charges straight back through her once.
  - The body yaws only inside the clip's airborne window, so planted feet never skid.
  - A sidestepped charge leaves it staggered for 1.4 s.
- **Horn ram** (the point-blank `heavy`, x1.8): a landed hit throws her 4 m away from it (`heavy_shove_m`, new hook `TacticalBrain.landed`).
- **Snap bite**: the point-blank basic.
- **Turning**: `turn_rate` is 2.0, so it turns badly at speed. Its flank is the safe side.
- **Hits use the attacking part.** The hitbox system (claude/mmo-hitboxes) is not on canon. As the brief allows, `pipeline.hit_parts` names a bone and a radius per move: Jaw 1.6 m for the bite, Head 1.9 m for the ram and the charge. `Creature.part_reach` checks that bone's posed position at the hit frame.
  - Under its chest or at its flank the jaws miss. `t_sp_carnotaurus` checks a flank miss at 3 m from its centre.
  - The shortcut is marked in the code. Move it to hitboxes.json when that branch lands.
- **Alphas**: any species can set `pipeline.alpha_texture`, and its alphas wear it (`CreatureView.apply_alpha_skin`, called in `Creature.spawn` before the colour rebind).
- **Spawns**: one on desert_35's far shore and one in desert_50's working ring. The lab lists it because it has a model.
- Every number is an ASSUMPTION, logged as CA1-CA6 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## How to test (god mode)
1. Double-click `tools/fight_lab.command` (point its REPO at this worktree or at canon once merged). Or run `Godot --path game -- --lab=creature_lab --god --skip-charcreate`. God mode is on (key G toggles it).
2. Press SPAWN, pick **Carnotaurus**, set the nature to Aggressive, then SPAWN. Turn "Alpha: ON" first to see the rust-and-black alpha. NEXT (key T) also cycles to it.
3. Stand about 15 m away. It roars, then charges head-low. Take the hit (you are hooked to the side and thrown), or roll sideways (it misses and stands staggered).
4. Watch the end of its line: it hops round to its left in the air and charges back once.
5. Walk up to its head: snap bites, and the horn ram (a bellow, a foot scrape and the head dropping, then the hit throws you back about 4 m). Go to its flank and its jaws miss. Debug F3 prints each move.

## Shots (`docs/orchestration/reports/sp-carnotaurus/`)
They come from windowed lab runs off-screen (`--position 6000,3000`, `-- --skip-charcreate --lab=creature_lab --species=carnotaurus --clipshots=DIR --clips=...`). The runs quit by themselves, with the HUD hidden and the survivor beside the snout for scale.
- `contact_sheet.jpg`: 3 frames per clip, two clips per row, in this order: idle, walk / run, charge / strafe_left, strafe_right / walk_back, alert / attack_primary, attack_heavy / charge_turn, hit_react / knockdown, death / sleep, feed.
- `hits.png`: the snap bite and the horn ram on their hit frames (saved on the `attack_hit` event), and charge_turn in mid-air.
- `lab_selector.jpg`: the spawn panel with Carnotaurus picked. `alpha_skin_blender.png` compares the regular and alpha skins.

What read wrong and was fixed:
- the four-legged first mesh (re-generated);
- the jaw closing the wrong way (`--x-side`);
- the raptor's whippy tail standing up in the attacks (countered);
- the heel sinking (ankle moved to the heel);
- the toes swinging under the floor in the walk (no curl or roll);
- the donor idle's feet off their prints (re-authored);
- the bite and ram landing at 3+ m head height (dropped to about 2.5 m);
- the survivor's auto-attack flashing the animal red in the lab shots (the lab now pauses her).

## Gates (after merging canon aba7ecc3)
- `tools/gait/check_carno.py --height 5.74` (new, adapted from check_ankylo): **CARNO_CHECK PASS**, 16 clips. It checks:
  - stretch (worst 9.7 in sleep);
  - floor (lowest -0.011 m);
  - moonwalk;
  - feet planted in the bite and the roar (toes within 0.5 cm);
  - the attacking part 6.3 m ahead and moving at the hit;
  - charge_turn: feet planted on the ground phases (3 cm) and 0.9 m up in mid-air.
- `python3 tools/audit_gaits.py --gate`: GATE PASS.
- `game/tests/t_sp_carnotaurus.gd`: **PASS**. It checks:
  - the model and 16 clips load, with no boxes, a Jaw, and the right size;
  - the alpha skin swaps the albedo;
  - the feet stay on their prints in the standing clips;
  - the bite lands in front and misses at the flank;
  - the ram lands and throws her 4.9 m;
  - the charge hits, turns 206 deg only in the air (0 deg before take-off) and comes back;
  - the spawn rows and the lab list are right.
- t_noboxes, t_combat, t_canim, t_data, t_ai, t_zebra, t_tactical, t_styraco, t_swarm, t_labspawn, t_sp_pachycephalosaurus, t_sp_megaloceros, t_coelomoves, t_compyfeel: PASS.
- `run_all.gd`: `[tests] PASS`. `tools/smoke.sh --no-import`: SMOKE PASS.
- t_ai and run_all now expect 21 species. Bump them again if another new species merges first.

## For the next agent / known issues
- **Merge notes:**
  - `tactical_brain.gd`, `creature.gd` (part_reach, alpha skin call), `creature_view.gd`, `creature_anim.gd` and `creature_clips.gd` gained small additive hooks; take both sides on merge.
  - `anim_events.json` has a `charge_turn` row and a `natural_speeds.carnotaurus` row. The natural speeds are the make_gait ground speed x the model scale, not a Godot bake.
- **Collider vs. visible body:** the body collider sits at the bbox centre, and the head is about 5 m ahead of it. Melee reach (attack_range 4.6) and the part check cover that. A BIGREACH-style collider fit was not done.
- **Clips I left as they are:**
  - knockdown and death are the donor's collapse, with the feet starting from the donor's spot. It reads fine lying down, but the idle-to-knockdown blend slides the feet.
  - feed brings the head down to about survivor height, not to the ground.
  - sleep is the velociraptor's curl.
- **Not done:**
  - no saddle or mount role (CA1), no eye-glow points, no ragdoll profile, no butchering row;
  - the alpha has no heavier osteoderm geometry; the skin is texture only (CA6);
  - `docs/current/biome-spawns.md` was not regenerated.
- The skill's external verifiers and the clip-viewer recordings are not on this machine; I used the repo's gates instead.
