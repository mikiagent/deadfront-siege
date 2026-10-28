# Overnight build, 2026-10-28 (05:20Z to 09:30Z)

Everything below is merged and pushed on `claude/mmo-overhaul` (head 9a441f67). Each merge passed its own tests, the
full suite (`[tests] PASS`) and smoke (`SMOKE PASS`).

## Landed

| Package | What you get | Built by |
|---|---|---|
| Pet follow | Tames keep their own slot around you inside a radius; Loyal ones stay closer | DeepSeek |
| Status effects | A box beside the survivor per status (bleed = red claw), blood drips, red screen edge, red tick numbers | Claude |
| Deinonychus AI template | Tree ambush; combos of backstep, power strafe, then pounce, charge or leap-in chomp; rare basic bite; chases when you leave; hurt stun = hurt clip length. Wiki: `docs/current/enemy-ai-template.md` | Claude |
| UI redesign | Nav menu; toasts, radials, dialogs; Character, Skills, Orders; Craft + place materials; Build drawer; Animals; World Atlas; Harbour cards; Island Market (offline card in single player); Domain; Communication; Radio University; Taming Pen; Island pick; gather pie + yield card; combat HUD with gold NET | Claude (7 agents) |
| Shared screen style | One header/back/close/tab/button style for every full-screen menu | Claude |
| Rare material attributes | 5% green-pip roll from each material's own list, carried into crafts from slot 1 | DeepSeek |
| Cooking roles | Main / topping / sauce / broth / spice slots; dishes inherit from the exact ingredients | DeepSeek |
| Butchering | Choose which carcass parts to cut; cut budget from Butchering level | DeepSeek |
| Taming odds | "Tame 64%" on the plate before you throw; bait improves grade | DeepSeek |
| Building quality | Pieces and stations take level and traits from their materials | DeepSeek |
| Outputs by material | `Crafting.output_for` mechanism (no recipe uses it yet; see A6) | Claude (after a stalled DeepSeek run) |
| Skill tree coverage | Every node marked active / partly active / not active yet; spec 12 catalogue as data | DeepSeek |
| Docs | Every `docs/current` page checked against the code; roadmap statuses updated | DeepSeek + me |
| Art from the art thread | Dodge clips, leap foot fix, megaloceros gait, zebraceratops weights, herbivore kick/charge, new jaws | art thread |

## Waiting on you

1. **Eye trails, round 2** (`claude/mmo-eyetrails2`): A/B images were posted in the thread. It's a flame shader and about 4x cheaper.
2. **Sky shadows** (`claude/mmo-skyshadows`): cloud shade and pteranodon shadows. Shots are in that branch's
   `docs/orchestration/reports/skyshadows/`. Trees, rocks and creatures don't darken under clouds yet.
3. **Ragdoll deaths** (`claude/mmo-ragdoll`): they replace death clips with physics. The deinonychus lies flat and small dinosaurs
   no longer stretch on slopes; 5 of 715 lab cases still fall back. Shots are in that branch's `docs/orchestration/reports/ragdoll/`.
4. **Open question A6** (`docs/vision/WildLandsMMO_Open_Questions.md`): which recipe families make different items by
   material, and whether those items need their own cost and skill gate.
5. **Earlier gates still open:** the lighting A/B (`claude/mmo-lightport`); the material look save field (`claude/mmo-matlook`), which
   holds crafted tint and the building look; the islands2 save and starter-size calls.
6. **New species** (apex raptors, dilophosaurus, smilodon) have no assets, so nothing was done for them.
7. **Nav menu call I made:** Island Market took the greyed-out Friends slot, since there's no friend system yet.

## Failed or reassigned

- **DeepSeek "outputs"** read for 2 h without writing code, then hit a provider error. A Claude agent did it.
- **DeepSeek ragdoll round 2** got stuck on physics tuning. A Claude agent finished it.
- A provider outage at 08:42Z ended two DeepSeek runs. One was restarted on GLM and finished.
- **Flaky test:** the deinonychus AI test failed at random under load until a Claude agent made it seed-identical.
- **DeepSeek patch proposal** (file-first budget, runner-side visual judge, retry on provider errors, and more):
  `docs/orchestration/dsc-patch-proposal.md`. Logic tasks mostly succeeded cheaply ($0.14 to $0.50 each); visual work and
  open-ended exploring are where they fail.
