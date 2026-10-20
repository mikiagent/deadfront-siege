# Tripo megaloceros gait trial

Credits: 35 of a 60 cap (3240 -> 3205). Rig f0bb7b28-6b0c-4729-8a7e-4f4939a7f57d (25),
retarget preset:quadruped:walk db60dfe1-13af-4fce-84b4-dcccd3be1ca6 (10). Rejected and refunded (1004 invalid
input on a quadruped rig): preset:run (d1970e64), preset:idle (50339598), walk+run batch (55924ce6).
Rig-check 7d24d5a1: riggable, quadruped.

Quadruped presets: only `preset:quadruped:walk`. Generic run/idle are refused on a quadruped rig.

Shipped: `game/assets/creatures/megaloceros/tripo/walk.glb` (in-place, 2.6 s) and the throwaway lab
`--lab=tripo_meg_lab --out=DIR` (side-view frames, foot-end positions per sample, contact sheet).
Not wired into creature data.

Measured (foot chain ends, 48 samples a cycle):
- Current game walk already alternates: L/R antiphase (corr -0.85 front and back), stride ~0.12 m, lift ~0.12 m.
  Current run is a trot (diagonal pairs in phase, L/R antiphase, corr -1.00), stride ~0.19 m.
- Tripo walk alternates too, stride 0.24-0.63 m, lift 0.10-0.13 m, but feet drift 0.19-0.27 m sideways
  (hind legs scissor across the midline), one hind foot dips 1 cm below ground, the near front hoof stays curled,
  no head/neck/Spine_0 keys (18 channels), and the skeleton is asymmetric (4 bones on one side, 5 on the other).
- Mesh and texture survive the rig; no tears seen.

Verdict: not significantly better. Do not replace.

Replacing would mean a new 34-bone skeleton with Tripo names; every clip (idle, alert, feed, attack_primary,
attack_heavy, hit_react, knockdown, death, sleep, run) would need re-authoring on it. Tripo presets cover none of them.
natural_speeds in anim_events.json would need a rebake. No saddle or bone-name code depends on the old skeleton.
