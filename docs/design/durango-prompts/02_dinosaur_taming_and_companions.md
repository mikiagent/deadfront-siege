# Claude implementation prompt: Durango-inspired Dinosaur Taming and Companions

Implement the entire *Durango: Wild Lands*-inspired **hunt → weaken → capture → transport → tame → bond → train** loop. This prompt describes the animal system; the separate **07 Combat and Capture** file specifies combat-facing capture interactions. **Build ONE shared capture subsystem used by both prompts, never two separate capture implementations.**

## Capture prerequisites and persistent captured animal
Unlock species/category capture eligibility through Survival → Animal Taming skills. Higher-level targets demand appropriate abilities; initial quadruped capture near level 15 is a historical reference. Capture success depends on target HP, incapacitation state, target level/species difficulty, and player Capture Ability. The actual combat stun/net interface is specified in file 07. Successful capture removes the wild actor and creates one unique captured-animal inventory instance preserving species, level and individual properties. Failed attempts may allow subsequent attempts after recovery. Keep exact captured-item ownership and large inventory-space requirements configurable.

## Physical taming pen
Craft/place a taming pen, deposit a specific captured animal, start a timed job, inspect remaining time/success chance, and offer appropriate food to affect duration or chance. Early Zebraceratops approximately one-hour taming is a historical guide reference, not a universal rule. Diet groups herbivore/carnivore/omnivore; validate food items and consume them exactly once. At completion, resolve success or failure once. A failed tame can mean escape/loss; success produces a claimable tamed creature. Offline timers must be timestamp-based and authoritative if supported. Handle destroyed pen, full output/storage, duplicate completion, and reconnect/reload.

## Bonding and companion ownership
Claim and bond a successfully tamed animal. Maintain owner, unique companion ID, species, level/XP, rank, attributes, individual traits, hunger, lifespan, HP, abilities, cargo and command state. Use seven bonded animals as a historical guide reference, configurable by design. Tame success, bonding and summoning are different states. Random S/A/B/C companion quality tiers with configurable odds and upgrade potential are an initial reconstruction of player-reported rank mechanics, not universal source-confirmed probabilities.

## Roles, progression and care
- Mounts: appropriate species are rideable, with distinct speeds and mount/dismount behavior.
- Cargo carriers: distinct persistent inventories per dinosaur, integrated with nonstacking unique-item storage.
- Combat companions: follow, defend, attack designated targets, take damage and return to the player. Integrate with actual combat AI.
- Training: earned companion XP, stats, species skills, roles, milestone unlocks.
- Care: species-based diets, hunger, housing, optional age/stat degradation and longevity items, optional resource production.
- Commands: Follow, Stay, Attack, Defend, Mount, Dismount, Feed, Cargo, Dismiss/Store.

## UI and tests
Create wild-target capture eligibility info, a capture result, taming-pen timer and feeding interface, claim/bond action, and management panel for companion rank, level, stats, commands, diet, age and cargo. Test success/failure transitions, exact identity preservation, offline taming, rank distribution, save/load, mount movement, cargo persistence and companion limits. Prioritize working end-to-end Zebraceratops capture and taming before extending species content.

## Implementation standards
Inspect the existing project and its architecture first. Reuse existing gameplay, inventory, persistence, UI, and network components rather than introducing parallel systems. Implement working code in the project's language and engine, not just pseudocode. Separate definitions/configuration from saved runtime state. Make balancing parameters configurable. Preserve unique instance IDs and enforce atomic ownership/currency transitions. Where multiplayer exists, validate gameplay authoritatively and make retried operations idempotent. Include tests and summarize modified files, verified behavior, assumptions, and remaining limitations.

**Historical fidelity:** Durango: Wild Lands was updated during 2019; published guides can describe different revisions. Distinguish verified original mechanics from contemporary player reports, community reconstruction formulas, and new design choices. Do not claim illustrative values are exact original Nexon server values.
