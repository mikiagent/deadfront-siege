# PARTCOMBAT: body sections, Wounds and Armor breaks, aimed ranged, two heavy blades and the bow

Branch `claude/mmo-partcombat`, from `origin/claude/mmo-overhaul`, with overhaul merged in before the final gates. Not
merged to canon. No credits spent (meshes and clips made in Blender from scripts).

Owner (Milan), verbatim: "when attacking with a ranged weapon (we should add/test bows soon) I want to be able to click the
intended body section. Crits should be small and hard to hit, so like a ranged weapon would be aiming at the crit but
hardly hit it unless the animal is staying still or the projectile velocity is high. Melee weapons should make their own
crits by attacking and focusing the same body part, it should form a crack in armor (Armor break) or a gash in the skin
(Wound) and targeting the armor break allows you to damage and targeting the wound allows you to crit". Then: "I want you
to test this with a greatsword and a bow", two heavy blades (a one-handed drag slab, a bigger two-handed blade), and the
bow on the two-hander's tier.

How it works: `docs/current/body_sections.md`. Assumptions: PC1-PC12 in `docs/vision/WildLandsMMO_Open_Questions.md`.

## What shipped
**A. Body sections** (`game/scripts/combat/body_sections.gd`, data `hitboxes.json sections`):
- Every species' hurtboxes grouped into head, neck, torso, belly, foreleg/hindleg L/R, tail, plus frill (triceratops,
  styracosaurus, zebraceratops), plates (stegosaurus) and hump (woolly rhino). Bone-name rules and splits in data; no
  per-species code.
- armoured flag in data (ankylosaurus back, tail and head; stego plates; ceratopsian frills; the pachy dome); crit flag
  computed from the crit spots, which all sit inside a section.

**B. Wounds and Armor breaks** (`body_wounds.gd`, wired into `Hunt.land_hit`):
- Melee build-up per section: slash -> Wound on skin, impact -> Armor break on armour, pierce -> both at 0.5 (PC4,
  Combat_Math: "Pierce concentrates force"). Switching sections halves the others; idling decays.
- Armor break lifts the x0.25 armour cut on that section. Wound: hits there are sure crits x2.0 and it bleeds
  (`bleeding_target`). Red gash / glowing orange crack decals ride the bone; WOUND! / ARMOR BREAK! float once; WOUND -N!
  on crits through it; "-N ARMOUR" on cut hits. They last until 30 s without a player hit.
- Focus: the AIM chip on the target card (`section_picker.gd`, 64 px chip and grid), or a tap on the body of the animal
  she fights. The pick glows cyan (`section_highlight.gd`); melee walks to and swings at its nearest reachable capsule.
- **Iron Slab Blade** (one-handed): cross-slash 3-combo (slash, cross back, a powerful third), impale (pierce, pulled up
  and out, back to ready), heavy chop (impact + slash). Dragged behind her at idle, walk and run.
- **Steel Greatblade** (two-handed, broad dark mottled steel with a ridged diamond section, bright ground edges, a
  ricasso, a long wrapped grip and a hard angled point): dragged behind her; overhead slam (lifted from the drag over her
  head and slammed down; impact x2 + slash, the main Armor-break move); bat sweep out and back (two hit windows).
  Both fists on the grip (tested).
- Moves come in chains per weapon (`hitboxes.json survivor.weapons.<class>.chain`); each move has its clip, hit windows,
  channels and damage_mult. The hitbox capsule rides the blade (tip within 0.2-0.25 m of the mesh tip at the hit frame).

**C. Aimed ranged and the bow** (`Hunt.aimed_shot`, `StoneProjectile`):
- The stone throw (slingshot) and the bow fly at the picked section's live point (its crit spot when it holds one; the
  torso with no pick) with spread from `Hunt.shot_sigma` (grows with target speed and distance, shrinks with projectile
  speed); the target keeps moving while the shot flies.
- Shots are judged against hurtbox capsules, not the collision capsule: the known limit (CS6) is fixed, a T. rex head
  can be shot. Armour and Wounds apply to shots.
- **Bow variant picked: the PRO-Class Bow.** No bow item existed in `items.json` / `recipes.json`; the variants exist in
  the Durango catalog (`docs/design/durango-prompts/34_crafting_materials_catalog.md`): Standard (Workbench Lv 15+),
  Improved (Lv 40+) and PRO-Class (Weapon Workbench Lv 50+). The Steel Greatblade is on the steel / PRO rung (one above
  the slab blade's iron / Improved rung), so the bow is the PRO-Class one. Recipe until limbs and tangs exist: 3 bone,
  1 steel, 1 bowstring at the workbench (Bow 1 node). Arrows: 1 wood + 1 stone make 5. 40 piercing, 30 m, arrows 45 m/s
  against a stone's 18.
- Bow clips draw, aim hold (her idle while she has a target) and release, built in Blender on the survivor rig (not the
  throw clips); the bow rides her left hand.

**Fight lab**: a WEAPON button (key B) cycles the slab blade, the greatblade and the bow (with 200 arrows).

## How the owner tests it in the fight lab
1. Double-click `tools/fight_lab.command` after this branch lands in canon (or run the line in `docs/current/fight-lab.md`
   against this worktree: `/Applications/Godot_mono.app/Contents/MacOS/Godot --path /Users/milankinzy/Documents/deadfront-siege/.claude/worktrees/mmo-partcombat/game -- --lab=creature_lab --god --skip-charcreate`).
2. **One-handed slab blade**: press WEAPON (or B) once. She drags the slab behind her. Press NEXT until a velociraptor
   (or SPAWN one). Let her auto-attack: cross, cross, big cross, impale, chop. Tap the AIM chip under the target bar
   and pick Body (or tap its flank): after three slashes on the same section a red gash opens with "WOUND!", and every
   later hit there reads "WOUND -N!" (a crit). Switch sections and the build-up halves.
3. **Two-handed greatblade**: press WEAPON again. NEXT to the ankylosaurus (or spawn a stegosaurus), AIM Body (the
   ankylosaurus back, tagged ARMOUR) or Plates. Hits read "-N ARMOUR" until two overhead slams crack it: an orange
   glowing fracture and "ARMOR BREAK!", then full damage there. The bat sweep hits on the way out and on the way back.
4. **Bow**: press WEAPON a third time (arrows come with it). Pick a target, then AIM Head (or tap the head). She draws,
   holds and looses; the arrow hits the hurtboxes of the picked section. Against a standing animal most arrows at a
   head marked WEAK land in the weak spot ("WEAK SPOT -N!"); against one running across they miss the spot and hit
   around it or nothing. Try a T. rex head: it can be shot now.
5. H shows the hurtboxes (green) and crit spots (magenta) as before.

## Shots (`docs/orchestration/reports/partcombat/`)
All from windowed off-screen runs that quit themselves, 1688x780 (844x390 at 2x):
`Godot --path game --position 6000,3000 --resolution 1688x780 -- --skip-charcreate --lab=partcombat_lab --out=DIR`.
I looked at each one.
- `1_section_picker.png`: an ankylosaurus side-on, the AIM chip open into its grid (Body ARMOUR, Neck WEAK, Head ARMOUR,
  Tail ARMOUR, Belly WEAK, the four legs), Body picked and glowing cyan on the animal.
- `2_wound_slab_blade.png`: real Iron Slab Blade swings (Hunt.begin_swing through the hitboxes, focus on Body). The
  section the blade reached first, the velociraptor's tail in the last run (its torso in an earlier one), got three
  slashes: the red gash on it and the "WOUND!" float. The lab stops her from walking, so she swings from where it puts
  her.
- `3_armor_break_greatblade.png`: the glowing orange fracture on the ankylosaurus back and the "ARMOR BREAK!" float (fading).
  Caption: SCRIPTED. In 50 s of real greatblade swings no slam pair landed on the back without the sweep landing on a
  leg in between (switching sections halves the build). The break then came from two `land_hit` calls with the slam's
  hit data. `t_heavyblade_2h` checks a live auto-attack landing hits; that the slam builds a break is checked on stego
  plates.
- `4_bow_aim.png`: the PRO-Class Bow in her left hand at full draw (the aim hold), the tyrannosaurus head picked and glowing.
- `5_arrow_hit.png`: a real fire_ranged arrow: it hit the tyrannosaurus head section, in its weak spot ("WEAK SPOT -10!",
  gold flash). Before this change the head could not be shot.
- `6_greatblade_closeup.png`: the Steel Greatblade dragged at her side. The ridge, the bright edges, the ricasso, the
  wrapped grip and the angled point all show. The mottled cloud patches are faint in this lab light.
- Clip contact sheets: `--poses [--weapon=id]` (not committed). I looked at the drag carry, the combo, the impale, the
  chop, the slam, the sweep and the bow draw, aim and release.

## Gates (final tree, after merging origin/claude/mmo-overhaul at ed28ee83c)
- New: t_bodysections PASS, t_wounds PASS, t_aimedranged PASS, t_bow PASS, t_heavyblade_1h PASS, t_heavyblade_2h PASS.
  - t_aimedranged, 40 seeded arrows per case: a still raptor head spot 80 %; running across at 8 m/s 0 %; at 2 m/s the
    arrow 80 % and the stone 0 %; the T. rex head section 100 %.
- Existing: t_critspots PASS, t_hitboxes PASS, t_combat PASS, t_knockdown PASS.
- t_stunlock is flaky on canon too. It failed 2 of 3 runs on this branch, each time a different species (the pachy's
  hits never landing, or the spinosaurus landing none on her). It passed once before the merge. On a clean
  origin/claude/mmo-overhaul checkout it passed once and then failed the same pachycephalosaurus check. Not caused by
  this branch.
- run_all `[tests] PASS`; `tools/smoke.sh --no-import` SMOKE PASS.

## For the next agent
- A new species gets sections automatically from its bone names; check `t_bodysections` and add `sections.species.<id>`
  for armour or a split (frill, plates, hump).
- A new heavy weapon: a `survivor.weapons.<tool_class>` row with its blade capsule and `chain`, `survivor.moves.wpn_*`
  rows, clips from `tools/make_heavy_weapon_clips.py` (key the grip, blade direction and edge per key), and a
  `props_manifest.json weapons.<id>` row (scale, grip_frac, hand, carry).
- Not done: the bowstring does not follow the drawing hand; no dust where the blades drag; the sweep hits one target
  only (HB3), so it does not cleave several animals; ranged hits build no Wounds (PC4); the server's `act.attack` knows
  nothing of sections. The live weapon damage at level 30 is high (the stats-per-level curve, not touched: balance pass).
