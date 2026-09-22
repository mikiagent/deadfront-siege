# Rig revision 3 for the nine transplanted species

Date: 2026-09-21 (work done 2026-09-20/21, committed with the Cursor handoff). Agent: Claude
Code (art pipeline). Meshy credits spent: 0 (re-rig only; meshes unchanged).

`tools/transplant_rig.py` v3 re-fits the Quaternius donor skeleton to real anatomical landmarks
(quadruped landmarks for ceratopsians and Megaloceros, hip/knee/ankle chain for bipeds), weights
with a continuous spine and single-limb influences (max four), and authors a dedicated 0.6 s
hit_react recoil with planted feet plus a knockdown that ends grounded. Every species under
`game/assets/creatures/` except the untouched specs (allosaurus, ankylosaurus, brachiosaurus,
dilophosaurus, smilodon, styracosaurus, tarbosaurus, triceratops, tyrannosaurus, which have no
mesh yet) was re-exported: coelophysis, compsognathus, deinonychus, gallimimus, megaloceros,
protoceratops, stegosaurus, utahraptor, velociraptor, and zebraceratops was built on it.

Each species JSON `pipeline` block now records `skeleton_transplant_v3`, the measured source
height and length, the warp landmarks, the weighting method and `rig_revision: 3`; `work/rig_manifest.json`
holds the same data next to the asset. Audit tooling: `tools/audit_creature_deformation.py`,
`tools/check_rig_audit.py` (before/after JSON in `tools/rig_audit_*.json`),
`tools/render_rig_review.py` (fixed-camera clip contact renders) and `tools/verify_rig_imports.gd`.

Validation: every clip remaps with `missing=0` in the home island lab; these assets have been in
the published packs since 20260921.2139.
