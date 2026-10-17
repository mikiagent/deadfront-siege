# Ship readiness and monetization

**Date:** 2026-10-16
**Method:** the survivor bot (`game/scripts/dev/bot_survivor.gd`) played the first hour on a fresh, isolated save, and the code and docs were read against the handoff's ship gate: desktop Chrome on the web build.
**Honest scope:** a bot can find blocked loops, bugs and pacing problems. It cannot tell us whether the game is fun, whether people will pay, or whether the stores will approve it. Those need human players and decisions only the owner can make.

## What the bot found, fixed and left open

| # | Finding | Status |
|---|---|---|
| 1 | A tameable animal bled to death inside the capture window, so the first tame failed with a blade | Fixed: a bleed or poison tick no longer runs once the animal is below the capture threshold. Regression test added. |
| 2 | A despawning corpse shrank its creature to a scale of exactly zero, so the physics body had a singular transform and the engine logged an error every frame for half a second | Fixed in two places: the fade now shrinks to a sliver, and creature movement skips a degenerate transform. |
| 3 | The "wet" status was re-applied every frame, in water and in rain, tens of thousands of times per run | Fixed: both paths now refresh once a second. |
| 4 | Bot runs wrote into the real save file, so later runs started from earlier progress | Fixed: bot mode uses its own throwaway save, deleted at launch. |
| 5 | In a real window the bot could not place buildings: the game's pointer variable never updated | Fixed in the bot. Not a player bug. |
| 6 | In a grove the screen shows many label chips. World labels already go through a collision layout and did not overlap each other in the frames seen | Open as a density question only. The one clipped label seen is item 8. |
| 7 | The bot's tame rung stalled on a 668 HP zebraceratops it never damaged: a compsognathus pulled the hunt onto itself and nothing pointed it back | Fixed in the bot, which now re-engages its target. A player would simply re-target. |
| 8 | The gather wheel decided which side of a hex a label sits on without knowing the label's width, so near a screen edge a label was clamped back over its own hex, or behind a neighbouring hex, and lost its first letters | Fixed. Labels now try right, left, above and below and keep the first spot clear of every hex and the title box. Unit tests cover it, and a 1600 by 900 screenshot of a wheel at the right edge shows all three labels readable. The screenshot lab now includes that case. |
| 9 | The bot's cook rung blocks when no corpse has been looted, because it has no way to get raw meat | Open, a bot limitation. A real player gets meat from a butchered carcass. In the last run it passed because it had looted a corpse. |
| 10 | The first tame at about level 5 is brutal. The bot's target was a 668 HP zebraceratops, a basic club hit it for about 0.3 damage, and the survivor died four times in 30 seconds before bleed wore the animal into the capture window | Open, needs a design decision. The post-kill retreat did fire. Decide whether the first tame should be reachable at level 5 and, if so, whether the first tameable should be a smaller animal such as a compsognathus. |

## Latest bot result

Fresh isolated save, headless, ten minutes:

| Measure | Result |
|---|---|
| Rungs reached | 14 of 14 |
| Engine and script errors | 0 |
| Walked | 1,157 m |
| Deaths | 4, all in one taming fight (item 10) |
| Time to first tame | 266 s |
| Slowest rung | route grind, 277 s |

Where the time goes: crafting rope 16%, gathering stone 14%, bark 12%, berries 12%. Early crafting is mostly waiting on gathering, which is the pacing a tester should judge.

## Gates a shippable build must pass

These come from the handoff and the gauntlet doc. Items marked done are verified in this session.

- [x] Unit tests and the headless smoke test pass.
- [x] A fresh-save bot run is isolated from the real save.
- [x] A fresh-save bot run clears every rung of the ladder, headless. A real-window run is still open because the windowed placement path needed a fix.
- [ ] Desktop Chrome soak on the exact deployed commit, with the stamp verified on the production alias.
- [ ] 390 by 844 phone layout checked for every screen touched.
- [x] No cropped gather-wheel labels at 1600 by 900, including near the right screen edge.
- [ ] Label density in a dense grove at 1600 by 900 and 390 by 844.
- [ ] Save migration tested from the previous schema.
- [ ] A first-time player reaches the first tame without help. This needs human testers.

## Monetization

### Recommendation

Free to play, with **cosmetic and convenience purchases only. Nothing that adds power or removes the fatigue limiter.**

Why:

- The Durango research and the systems PRD both name pay-to-win pets and paid fatigue relief as mistakes. Durango's premium pets carried paid power, and its fatigue items sold the game's own pacing back to players.
- Fatigue is the session governor. Selling relief from it would undercut the very system that keeps the game from being grindable.
- A single-player-first game cannot defend a paid-power economy against other players, but it can sell things players want to look at.

### What to sell

| Product | Type | Notes |
|---|---|---|
| Outfits and dye packs | Cosmetic | The tint-mask clothing system already supports recolours. |
| Base decor and furniture sets | Cosmetic | Fits the building system. |
| Pet and mount skins | Cosmetic | Same stats as the base animal. |
| Extra character slots | Convenience | Durango sold these. |
| Supporter pack | One-time purchase | Bundles a cosmetic set with a name in the credits. |

Avoid: paid fatigue items, paid stat pets, paid skill points, and random boxes. Random boxes also attract regulatory and store-policy scrutiny in several countries.

### What has to exist first

None of this exists in the repo today. There is no in-app purchase, account, analytics or privacy code.

1. **Accounts and entitlements.** A server record of what each player owns. Without it a purchase cannot follow the player across devices or survive a cleared browser.
2. **Payment provider.** Web: a hosted checkout such as Stripe through a Vercel serverless function. iOS: StoreKit is mandatory for digital goods, and the iOS app is parked while an Apple support case is open. Android: Google Play Billing.
3. **A cosmetic catalog and a store screen** behind a feature flag, working offline-first with no real payments, so the flow can be tested and the art budget scoped before any money is involved.
4. **Legal basics.** Privacy policy, terms, age rating, and consent for analytics. These are owner decisions and may need a lawyer.
5. **Analytics.** Without session length, rung drop-off and retention there is no way to tell a monetizable game from a pretty one.

### Decisions that only the owner can make

- Which platforms launch first: web only, or web plus iOS and Android.
- Whether to take payments at all before the loop is proven fun.
- Which accounts, keys and legal entity the payment provider is registered under.

## Recommended next steps

1. Finish the bot's fresh-save ladder in a real window and fix whatever it blocks on.
2. Check label density in a dense grove at 1600 by 900 and 390 by 844.
3. Run a desktop Chrome soak on an exact commit and verify the production stamp.
4. Add analytics events for the ladder rungs, behind a consent switch.
5. Build the cosmetic catalog and store screen behind a feature flag, with no payments.
6. Put a build in front of 10 to 20 real players and watch where they stall.
7. Only then wire up payments.
