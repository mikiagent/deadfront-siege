# claude-worldui: creature bars over the head, top target bar up close, resource tags without fly-in

Branch `claude/mmo-worldui` (from `claude/mmo-overhaul`). UI/HUD only: no brains, creature models or
integrator files touched.

Owner, 2026-10-31: "health bar bug on animals, it is appearing below the animal and i think it would be
better above the animal and disappearing when you get close (health bar at the top of the screen) ...
there was also a bug where resources would have a tag fly in and drop on the resource, it should just be
part of the resource".

## Root causes
- Bar under / inside the animal: the 114 px plate was placed 70 px over a point 0.3 m above the def
  height, so a full plate hung 44 px into the body (before_bars.png: the triceratops' bar across its
  back), and when a HUD block or the screen top was above it, `free_spot`'s fallback slid it below the
  animal (before_close.png: the compy's bar under it, bottom-left).
- Tag fly-in: `HudPills` laid every pill out from 8 m, where its distance alpha is 0, and remembered that
  (often stacked) row; when it faded in it glided 5 px a frame from that row down onto the resource.

## What changed
- `ui/creature_plates.gd`: anchor = top-centre of the skinned body's mesh bounds (rest pose, cached per
  size; the eye-trail ribbon is ignored, its box ran 2 m off a compy), pill bottom 6 px above it, centred.
  `lift_spot`: up only, else hidden. Stacking uses the drawn pill, not the 114 px budget, and eases lifts
  (480 px/s) instead of hopping. Distance fade 36-45 m; hidden behind the camera; position clamped (an
  off-screen animal at 1e10 px bent the plate's size via float offsets). Docking: when the top bar shows
  the animal its floating bar fades out; damage numbers stay.
- `ui/hud_target.gd` (new, split from hunt_hud): which creature the top bar shows (fight, desktop
  selection, nearest wild animal within 6 m of its body edge with an 8 m exit, last fought, MegaRex boss).
- `ui/hunt_hud.gd`: picks the target in `_process` (so the redraw signature sees a close animal), fades
  the bar in over 0.2 s, red BOSS tag for the MegaRex, `top_target()` for the plates.
- `ui/hud_pills.gd`: only a visibly drawn pill keeps a row to glide from; new pills sit on their anchor
  and fade in over 0.18 s. `last_drawn` rows carry the drawn rect, the laid-out rect and alpha.
- `dev/worldui_lab.gd` + `scenes/dev/worldui_lab.tscn`: the capture lab.
- `docs/current/hud.md` updated.

## ASSUMPTIONs (log in the wiki Open Questions)
- Close range 6 m from the body's edge, released at 8 m.
- On a landscape phone a merely close animal does not take the centre band from the expanded quest card
  or from a tapped selection (review r3: the selection's floating bar + swords hex need the room).
- No room above an animal (top of the screen, HUD above it): its floating bar hides rather than sit on
  or under it. Close up the top bar covers it; farther off it is out of view anyway.
- Plates fade from 36 m to the 45 m range edge. The MegaRex is the one "boss" (red BOSS tag).
- No cinematic camera exists, so nothing to hide for one; plates already hide under open sheets.
  Mounted keeps plates (mounted combat uses them).
- Not done: terrain/tree occlusion raycasts for plates (cost), head-bone following (the rest-pose box top
  is steadier and works for every species).

## Tests
- New `game/tests/t_worldui.gd`: compy and MegaRex pill bottom over the model top, above body middle and
  feet, centred, still; lift_spot never goes down (with a repro that the old rule did); close animal ->
  top bar + floating bar docked, hysteresis holds, walk off -> back; MegaRex close by its body edge;
  landscape phone close -> top band; rock tag's first visible frame equals its laid-out spot, sits on the
  rock's top, fades in.
- See the final reply for the full run (t_worldui t_ui t_hudrules t_fieldhud t_combat, run_all, smoke).

## Screenshots (844x390 at 2x, `docs/orchestration/reports/worldui/`)
before_bars / after_bars, before_close / after_close, before_tag_first_frame / after_tag_first_frame,
before_tag_settled / after_tag_settled. Before = canon `claude/mmo-overhaul` with the same lab.

## Notes for others
- `Creature.footprint()` (BIGREACH, creature.gd) merges every visible MeshInstance3D, including the
  eye-trail ribbon whose box follows past head positions; melee reach on a compy may be inflated. Not
  touched here (creature code is in flight elsewhere).
