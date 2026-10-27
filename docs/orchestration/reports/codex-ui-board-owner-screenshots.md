# Owner screenshots on the UI vision board

Date: 2026-10-27. The live wiki is in the `claude/mmo-overhaul` checkout.

## Shipped in the working tree

Added three recoverable owner-provided Durango reference screenshots to the UI vision board: taming-pen placement, taming success and companion stats, and melee skill selection with spent SP. The images live under `docs/reference/`; board cards link to the existing relevant design references. The original Desktop files remain intact. The images were compared with existing references for duplicates.

## Verification and handoff

All three images loaded through the wiki image API with bytes matching their source files. The seven wiki API tests passed, `node --check` and `git diff --check` passed, and `tools/smoke.sh` printed `SMOKE PASS`. No Meshy credits were spent and no gameplay assumptions were added.

The two later hamburger-menu screenshots mentioned in the OpenCode session were not located in its prior search and have not been added. Recover the actual files before adding them. The new image files and board change remain uncommitted in the shared canon worktree, which contains unrelated OpenCode changes and staged asset deletions; do not stage the entire worktree.
