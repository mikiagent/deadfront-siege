# Codex task C1 — prove image-to-3D on Utahraptor

You are the 3D art pipeline for a Godot dinosaur survival game. Text-to-3D has already failed three times on this species (upright tripod posture, stub tail). Your job is to find out, for at most **60 Meshy credits**, whether image-to-3D produces a correct Utahraptor silhouette. Do not rig or animate in this task.

## Read first
- `AGENTS.md` (ownership rules; you own `game/assets/creatures/`, `game/data/creatures/*.json`, `tools/meshy.py`, `tools/render_glb.py`)
- `docs/prd/dinosaur-roster-and-3d-pipeline.md` §4 (what failed and why, verified API parameters)
- `game/data/creatures/SCHEMA.md` (file layout and validation rules)
- `game/data/creatures/utahraptor.json` (the species spec; its `prompt` and `texture_prompt` are your text conditioning)
- `tools/meshy.py` (resumable driver; extend it, do not fork it)

## Environment
- Meshy MCP server is configured for you (`meshy_text_to_image`, `meshy_image_to_3d`, `meshy_get_task_status`, `meshy_download_model`, `meshy_check_balance`). First call `meshy_check_balance` and record the number. If the call fails with an auth error, stop and report: the key in `~/.codex/config.toml` may be revoked.
- For `tools/meshy.py`, export `MESHY_API_KEY` in the shell using the same key the MCP server uses.
- Blender is at `/Applications/Blender.app/Contents/MacOS/Blender`. Use it headless for renders.
- Old failed mesh for comparison: `game/assets/creatures/utahraptor/work/utahraptor_preview.glb`.

## Steps

1. **Render tool.** Write `tools/render_glb.py`: a Blender `--background --python` script taking `<glb> <out.png>` that imports the GLB, frames it, and renders a 2x2 sheet (left side view, front, top, three-quarter) at 1024x1024 with flat neutral lighting on white. Print the model's bounding box in metres and, if an armature exists, the bone names. Test it on the old preview mesh first so the tool is proven before credits are spent.

2. **Reference image.** Use `meshy_text_to_image` (model nano-banana-pro, 9 credits each, at most 3 attempts). The image is the geometry conditioning, so it must pin the two things text-to-3D got wrong: **spine parallel to the ground** and **a long stiff tail roughly half the animal's length**. Start from:

   > Orthographic left-side profile view of a Utahraptor, scientifically accurate palaeoart reconstruction, full body, spine held horizontal and parallel to the ground, long stiff tail extended straight back making up about half the total length, head level with the hips, short forelimbs with palms facing inward, enlarged sickle claw on the second toe of each foot, coarse shaggy proto-feathers on body, bare scaly hands and feet, rust brown with dark dorsal banding, standing on flat ground in a neutral walking pose, flat even lighting, plain white background, no shadow, no text, no scenery, entire animal visible with margin.

   Look at each result. Accept only if: tail is at least 40% of total length, spine within ~15 degrees of horizontal, no upright tripod pose, sickle claw visible, no frill or JP-style features. Save the accepted image as `game/assets/creatures/utahraptor/ref/utahraptor_side.png` and add an empty `.gdignore` in `ref/`. If none of three passes, stop and report; do not spend on 3D.

3. **Image-to-3D.** Extend `tools/meshy.py` with an `i2m <species>` command that posts the accepted reference to the image-to-3D endpoint and records the task id under `i2m` in `tools/meshy_state.json`. Confirm the exact request fields against the `meshy_image_to_3d` MCP tool schema before calling: use `ai_model` **meshy-t2** with `model_type` **smart-topology** (5 credits mesh, +10 textured), `topology` triangle, `target_polycount` 12000, `target_formats` ["glb"], texture on, PBR on, `texture_prompt` from the JSON. Meshy needs a reachable image URL or a data URI; a base64 data URI is fine. Max 2 attempts (30 credits).

4. **Validate.** Download the GLB to `game/assets/creatures/utahraptor/work/utahraptor_i2m_v1.glb` (this is not the final asset; the final `<species>.glb` is produced by rigging in C2). Render it with your tool to `game/assets/creatures/utahraptor/sheet.png`. Compare against the old preview mesh sheet. Apply the same acceptance rules as step 2 to the side view of the render.

5. **Report.** Write `docs/orchestration/reports/codex-C1-utahraptor-proof.md`: balance before/after, every task id, which image attempt was accepted and why, the render sheet path, a pass/fail verdict per criterion, and what C2 should change (prompt wording, fields, whether a second view via multi-image would help). Update the `pipeline` block in `utahraptor.json` with the task ids. Commit only files you own.

## Hard limits
- 60 credits total. Stop at the cap and report even if the result is not accepted yet.
- Do not call text-to-3D. Do not rig. Do not touch `game/scenes` or `game/scripts`.
- Do not delete the old preview mesh; it is the "wrong" reference.
