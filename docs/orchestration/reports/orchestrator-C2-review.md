# Orchestrator review of C1 and C2 (2026-09-17)

**Verdict:** C1 accepted. C2 correctly stopped at the first hard blocker with 252 of 300 credits unspent. Codex's tooling (`i2m`, resumable stages, `render_glb.py`, clip validator) is kept.

## What the evidence says

- All three side silhouettes pass the C1 criteria: horizontal spine, tail about half the length, raised sickle claws, no frill. Image-to-3D solved the problem text-to-3D could not.
- Front views show real defects: Utahraptor has chest/neck holes, Deinonychus has a forked tail-feather fan and shoulder spikes, Velociraptor has stretched triangles and a weak claw. These are fixable in Blender and do not affect the rig decision.
- Meshy rigging API: "programmatic rigging currently only works well with standard humanoid (bipedal) assets"; the 422 text is "may not be a valid humanoid character". Confirmed against docs.meshy.ai/en/api/rigging on 2026-09-17. The Meshy web app auto-detects humanoid or quadruped only and offers walk as the only quadruped animation.
- Deinonychus's GLB unexpectedly contains a 62-bone animal skeleton (spine, neck, tail 0–6, four limbs, IK targets) with no animations. Useful as a rig reference; not a Meshy rig task.

## Contract changes made

- SCHEMA §3: the game normalises facing and scale from `pipeline.forward_axis` and `pipeline.source_height_m`. Assets no longer promise +Z or real size. This resolves Codex's orientation blocker without touching meshes.
- SCHEMA §2: clip fallbacks for optional clips.

## Routes for the owner to pick (C2b)

| Route | Automation | Cost | Risk |
|---|---|---|---|
| **Tripo auto-rig `v2.5-20260210`** | API, accepts GLB upload, rig types include `biped`, `avian`, `quadruped` | ~30 Tripo credits per rig, needs an account | Animation presets for non-humanoid rigs are undocumented; may still need Blender clips |
| **Blender Rigify** (installed, 5.2 LTS, has `bird` and `basic_quadruped` metarigs) | Scriptable by Codex, fully offline | Time only | Clip quality depends on scripted keyframes; slowest |
| **Meshy web app rigging** | Manual in browser, auto-detect | 5 credits | Likely misdetects a theropod as humanoid or quadruped; walk-only library |

Recommendation: Tripo for the rig, Blender for repairs and for any clip Tripo cannot provide. Prove on Utahraptor before touching the other two.

## Immediate unblock (no credits)

Use the CC0 Gobkit dinosaur pack (10 species, idle/attack/dead/walk, single GLB) as stand-ins so Cursor's M1–M3 can be seen and balanced with animated dinosaurs now. Carnotaurus stands in for Utahraptor, Oviraptor for Velociraptor and Deinonychus. They are replaced file-for-file when C2b delivers.
