# dsc SLOWFIX: land SLOWLEVELS on the new canon

In progress.

## Merge
- `origin/claude/mmo-overhaul` merged into `claude/mmo-slowlevels` (no conflicts).

## Combined suite
- `tests/run_all.gd` failed `econ: the torn bytes are cut from the file`. The test appended a torn
  journal line and searched the whole file for "9999"; a creature stat value in the run_all economy
  (`0.029999999999972715`) contains that text, so the search matched a good line. The torn line now
  carries a unique marker and the check looks for that.

## Status
- Merged canon; `run_all.gd` PASS; `verify_slowfix.sh` VERIFY PASS.
- The three owner requests that arrived mid-run (Skills-screen ghost fill, FULL + blocked bounce, no
  banked XP) are **not implemented**. Exact pointers for the next agent are in `.dsc/NOTES.md`
  ("State at the run's stop") and in the plan entries still unticked in `.dsc/PLAN.md`.
