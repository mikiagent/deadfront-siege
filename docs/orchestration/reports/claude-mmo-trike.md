# TRIKE: Triceratops concept sheet v01 (concept stage only)

Branch `claude/mmo-trike`, fast-forwarded to `claude/mmo-overhaul` ddaab662 before the work.

## What shipped

| File | What |
|---|---|
| `assets/concept-art/creatures/triceratops/concept-sheet-v01.png` | Clean sheet, 1672x941. Shows left side, front, top and rear three-quarter views of one individual. Pale grey studio background, no text, no scale figure. |
| `assets/concept-art/creatures/triceratops/concept-sheet-v01-review.png` | Labelled review copy, 1672x1001: the same pixels plus view labels and a DRAFT footer, drawn in HTML and captured with headless Chrome. |
| `assets/concept-art/INDEX.md` | New `DRAFT` row for Triceratops with an empty approval anchor. |
| `docs/orchestration/mmo/asset-replacement.md` | Triceratops now has its own row: IN PROGRESS under TRIKE, with the owner's rejection of the bake-off builds. |

The DeepSeek bake-off builds were not touched or integrated. Tripo was not called.

## How it was made (provenance)

The Deinonychus sheet v01 (commit 9df48851, 2026-09-21) was made by OpenAI image generation in the same 1672x941 house layout. The game-asset-pipeline skill gives the source order: (1) Codex `generate_image` or ChatGPT web, both free on the owner's plan; (2) Higgsfield GPT Image 2.5 as the paid fallback.

1. Codex (through the dsc image tool, as `bakeoff/make_refs.mjs` does) refused both attempts with "You've hit your usage limit ... try again at 3:29 AM". It produced no image and charged nothing.
2. ChatGPT web in the signed-in debug Chrome (port 9222, the dsc `chatgpt-image` route through `bakeoff/chatgpt_direct.mjs`) succeeded on the first prompt. This was conversation `6ad860ec-6718-83ea-8edd-dfb73f4409a2` on the owner's Plus plan. The tab was closed afterwards.
   - The image is a `blob:` URL that the dsc browser tool's `download` cannot fetch: it saved HTML.
   - Its `eval` also truncates long results.
   - The PNG was therefore read over raw CDP with an in-page `fetch` of the blob (a scratchpad script, not in the repo). The dsc chatgpt-image workflow has the same blob problem and should be fixed there.
3. Higgsfield was not used, so it needed no balance check.

**Credits spent: 0.** No Meshy, Tripo or Higgsfield calls were made.

The prompt (ChatGPT text-only version) asked for:
- the four views in the Deinonychus layout, with no text and no human figure;
- a neutral rest pose;
- exactly three horns, a solid frill with epoccipitals and no holes, and a hooked beak;
- the hips as the highest point and hind legs longer than the front legs;
- four-toed hind feet and blunt hooves;
- a short, thick, tapering tail;
- colours from `game/data/creatures/triceratops.json` `texture_prompt`: dark olive pebbled hide, a rust frill, a pale belly, ivory horns and a matte surface.

## Checked by eye (full sheet plus zoomed crops of the heads, legs and rear view)

- Three horns in every view: two long brow horns and a short nose horn. The frill is solid with triangular epoccipitals, and the beak is hooked.
- The hips are higher than the shoulders, and the hind legs are longer and heavier than the front legs. All four feet are planted, with blunt hoof-like claws. Nothing is cropped (the rear-view tail tip ends about 25 px from the edge), and the four views show the same colours and markings.

Noted for the owner:
- The rear three-quarter view is from behind-LEFT, not behind-right as asked. The approved Deinonychus sheet is drawn the same way.
- The brow horns splay a little wider in the top view than in the front view.
- The tail is long and tapers to a fine point.
- The pebbled scutes on the flanks are fairly busy.

## Gates

This is a concept-stage package, and no file under `game/` changed: the diff is `assets/concept-art/**` plus two docs. None of these were run:
- creature-verify
- the `t_*.gd` tests and run_all
- smoke
- creature_anim_lab
- windowed shots

They apply once a mesh and rig exist. There were no Godot or Blender runs.

## Open points for the owner and the next agent

- **Size conflict in the data:**
  - `triceratops.json` has `real_length_m: 18.0` and `height_meters: 6.0`.
  - Its `look` text and the roster PRD say 9 m.
  - This task said "about 6 m long".
  - The sheet has no scale figure, so the conflict has to be settled before the mesh is scaled.
- **After approval:**
  1. Record the approval anchor in INDEX.md and set the row to `APPROVED`.
  2. Make four clean views with the approved sheet attached (Codex resets after 3:29 AM, or use ChatGPT web). Never crop the sheet panels.
  3. Run Tripo multiview `P1-20260311` (50 credits per generation observed), then the Stegosaurus v2 route (rig, 9 clips, `creature-verify.mjs`, integration).
  4. A credit cap is needed from the owner; one generation plus one retry would be 100 credits.
- **W2-RAGDOLL:** `game/data/creatures/ragdoll.json` on `claude/mmo-w2-ragdoll` has no triceratops profile, so nothing needs re-tuning now. A profile is needed once the rigged mesh lands.
- **Leftover files:** the work tree already held untracked `game/scripts/dev/creature_pose_lab.gd` and `game/scenes/dev/creature_pose_lab.tscn` from an earlier run (2026-10-20, triceratops pose shots). They were left alone and not committed.

## Fix round 1 (2026-10-21, after the paleo-art review)

The sheet and review copy were replaced in place (same paths, still `DRAFT`). The previous draft is in commit a775a83c.

### How it was made

- **Attempt that was blocked:** I tried to attach the old sheet and the Deinonychus sheet to ChatGPT as references. The session's permission classifier refused the upload, so every prompt in this round was text only.
- **Conversation `6ad8695b-5eb8-83ea-843f-a865ce7db0d2`** (ChatGPT web, owner's Plus plan; scratchpad driver `trike2/tools/chat.mjs`):
  1. A fresh text-only generation with all the fixes written into the prompt.
     - It came out flatter and painterly, with better horns.
     - Its rear view was a front three-quarter view, and its tail was long.
  2. Edit: shorter tail and a true rear three-quarter view. The rear view came out right, but the tail became a stump.
  3. Edit: tail 1.6 times longer. It came back as long as v01.
  4. Edit: tail a quarter shorter, plus forefeet. This is the base for the final sheet.
- **Local post-processing (deterministic, scratchpad `trike2/tools/relayout.py` and `horns.py`):**
  - Removed two faint ghost smears that the edits left next to horn tips (side view and rear view).
  - Shifted the background to the Deinonychus value, RGB 200,197,192. Animal pixels were left alone.
  - Cut out the four views and placed them again at one common scale of 0.94.
    - The generator had drawn the top view at 0.85 of the side view's scale. I scaled it up so its beak-to-tail length matches the side view.
  - Bent the free ends of the two top-view brow horns outward by 17 px at the tips, so the tip spread matches the front view.
- **Review copy:** the clean pixels, plus view labels, two 1.8 m human silhouettes and a footer. The silhouettes are cut from the approved Deinonychus sheet. One is drawn at a 9 m body length (PRD and look text) and one at 18 m (`triceratops.json` `real_length_m`), so the owner can pick a size.

**Credits: 0.** No Tripo, Meshy or Higgsfield calls.

### Measured on the clean sheet

Threshold 40 against the background, the same method as the review.

| Review item | Before (v01) | Now |
|---|---|---|
| 1. Brow horn tip spread / frill width | front 0.76, top 0.55 | front 152/269 = 0.57, top 149/267 = 0.56 |
| 2. Body width / frill width | front 0.93, top 1.13 | front 242/269 = 0.90, top 250/267 = 0.94 |
| 3. Tail, hind-foot centre to tip / length | side 34%, top 27%, needle tip | side 25 to 26%, top 26%, rear view short. The tip is blunt and rounded in all three views. |
| 4. Layout | top and rear panels interleaved, 5 px row gap | side-to-front 280 px, top-to-rear 152 px, empty row band y 479 to 529 (51 px), outer margins at least 24 px |
| 5. Side-view forefeet | 18 px overlap | about 14 px apart at the hooves |
| 6. Style and background | glossy render, background 190,187,185 | flatter painterly rendering, softer shadows, calmer scales, background 200,197,192 |
| 8. Scale | no figure | two figures on the review copy only |

### Still open, said plainly

- The tail is about 25 to 26% against the 28 to 30% asked. It is consistent across views and blunt. Three edits swung it between a stump and the original whip; this was the closest.
- The forefeet have separate blunt hoofed digits now, but they are not exactly three hoofed and two clawless. The reviewer called this acceptable at the ARK bar.
- The top-view horns were bent by a pixel warp, not redrawn.
- The views come from ChatGPT image edits, so the hide reads a bit browner than in v01. It is still olive, with a rust frill, pale belly and ivory horns.
- Size is still the owner's call: 9 m in the PRD and look text, 18 m in the json.

### Gates

These were not run, because this is a concept sheet and nothing under `game/` changed:
- creature-verify
- the t_*.gd tests and run_all
- smoke
- creature_anim_lab
- windowed shots

W2-RAGDOLL still has no triceratops profile (checked `claude/mmo-w2-ragdoll` 56890436), so nothing needs re-tuning.
