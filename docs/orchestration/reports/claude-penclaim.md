# PENCLAIM: tame result card + offline pen timer

Branch `claude/mmo-penclaim` (from `origin/claude/mmo-overhaul` 36d1fac8). Not merged to canon.

## What shipped

1. **Tame result + claim.** When a pen's wait ends, `TamingPen.resolve()` rolls once. Success builds the
   PetRecord (uid, grade from `genetics.overall_tier()`, nature, level) and holds it in the pen as
   `tamed`; nothing joins `player.bonded` until the player taps **Bond** (`TamingPen.claim()`), which checks the
   bonded cap and is idempotent: the record leaves the pen in the same call, and a uid that is already on the
   roster is never added again (double tap, or a reload of the pre-claim save). **Keep in pen** closes the
   card; the pet stays in the pen, saved, and the card comes back on the next pen tap. A failed roll frees the
   animal (a notice now says so), and the pen keeps nothing to claim.
   The Taming Pen screen shows a gold **Taming successful** card for a ready pen: grade stamp, species,
   `Lv. N · Generation 1 · Nature`, Bag / Max HP / Speed / Attack / Defense, Keep in pen + Bond (64 px at
   844x390, 76 px desktop). The card swaps in live if the wait ends while the screen is open.
2. **Timestamp timer.** `TamingPen.end_at` (unix seconds) is the timer; `remaining` is now a property
   computed from it (setting it moves `end_at`, so feeding moves the end time and every old caller keeps
   working). The time source is `TamingPen.now()` (wall clock read once per frame, plus `time_skew` for tests).
   A pen whose end time passed while the game was closed resolves once on its first frame. Old saves with only
   `remaining` convert on load (wait restarts from the load).

## Saved keys (additive, per pen building row)

| Key | Type | Meaning |
|---|---|---|
| `end_at` | float, unix seconds | when the wait ends; 0 = no timer. Shaped in `SaveSanitizer.BUILDING_ROW`. |
| `tamed` | PetRecord dict, only when a tame waits for Bond | sanitized with the same `_pets` checks as roster pets; ignored when the pen has no occupant. |

`remaining` is still written (a snapshot, so an older build can read a new save); `end_at` wins on load.
No other save change. Old saves load unchanged; t_save is green.

## Deviation from the brief

- **No `paused_left`.** The brief asked to keep a paused value while the pen is held at the bonded cap. With
  the claim step, the cap no longer holds the roll: the pen rolls on time and the pet waits in the pen; the cap
  is checked at Bond. So nothing is ever paused and no paused key is saved. (Open Questions PC1.) If the owner
  wants the old "do not roll at the cap", it is a small change in `_process` plus that key.

## Gates (all on the branch head)

t_pen_claim PASS, t_pen_offline PASS, t_pen_diet PASS, t_tamingodds PASS, t_tame PASS, t_save PASS,
t_w2_skills PASS, t_uiworld PASS, t_build PASS, run_all `[tests] PASS`, `tools/smoke.sh --no-import` SMOKE PASS.

Tests changed for the new flow: `t_w2_skills._test_pen_cap` (at 3/3 Bond is refused and the pet stays in the
pen, then Bond after the cap rises), `t_save._check_pen` (claims after the forced finish). `capture_lab` claims too.

## Shots

Off-screen windowed `uiworld_lab` runs (`--position 6000,3000`, self-quitting, `-- --skip-charcreate`),
new `pen_tamed` step: `docs/orchestration/reports/penclaim/pen_tamed_1600x900.png`, `pen_tamed_844x390.png`
(844x390 rendered at 2x). Min tap target 64 px in both.

## Assumptions (logged as PC1-PC4 in docs/vision/WildLandsMMO_Open_Questions.md)

PC1 roll at the cap, cap checked at Bond. PC2 generation 1 for pen tames; Bag = bag slot count.
PC3 packing up / demolishing a pen with an unclaimed tame hands the captured animal back (result dropped).
PC4 wall-clock wait counts while closed, away, or paused; old in-progress pens restart their remaining wait.

## Not checked

No real-mouse desktop Chrome or device run; no web export or deploy. Lifespan/age out of scope.
