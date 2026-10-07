# Tyrant standin evaluation

Quaternius Trex was selected over Gobkit Trex after rendered comparison. Gobkit is an orange, short-tailed cartoon with large eyes and three generic animations. Quaternius has a dark olive, long-tailed biped silhouette and Idle, Walk, Run, Attack, Jump and Death clips.

Godot 4.7's native ufbx importer converted the existing repository FBX to GLB. Embedded animation names were mapped to the runtime contract. No bone names, rests, stats, hitboxes or controller timing changed. Jump is a standin heavy attack, not a final authored stomp; hit react falls back to idle. The source FBX remains unchanged.

Posed source bounds measured in Godot are 14.67842 high and 30.8745 long. A model-only scale override normalizes height to the existing 8m catalogue height. This avoids the existing raw mesh AABB scale helper misreading transformed skinned assets. Axis remains -Z. Only this asset opts into the override.

Rendered 960x600 runtime view at camera size28 shows a readable full dinosaur silhouette beside the survivor instead of boxes. Default size15 crops the large animal. Survivor wearable appearance and final heavy animation still need hands-on review. No production deployment.

Combat evidence is separate: a copied earned-kit 1x segment ran70seconds with zero contacts and6076damage. A40x copied-save full kill demonstrated automation feasibility only. Clear time changes with acceleration; neither is human-feel acceptance.
