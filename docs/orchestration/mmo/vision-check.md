# Vision check (2026-10-20)

A read-only audit of the finish-6 packages against durango-prompts 01-12, the PRDs, docs/design and STATUS owner
decisions. The owner judged a full multi-agent audit too exhaustive, so it was stopped after 10 of 11 doc readers
finished, before their skeptic pass. The findings below are reader findings with doc line references; each package
checks the cited line before acting.

## Folded into finish-6 now (they touch files those packages are editing)

| Package | Fix | Doc |
|---|---|---|
| W2-DATA | Processing is mandatory: straps need dried hide, rope needs twine | PRD:531-533 |
| W2-DATA | No ore on the home grassland; metal starts on desert/volcanic islands | world-design.md:66 |
| W2-SKILLS | Non-functional nodes cannot be bought for SP | spec 12:215, STATUS "never an inert tree" |
| W2-SKILLS | Daily refund limit (5 free, max 10, configurable) | skills.md:9, spec 03:37 |
| W2-INV | Default consumption never takes the rare or higher-level instance | spec 05:23, 04:41 |
| W2-PROCESS | Stations use the instances the player picked | spec 08:98 |
| W2-PROCESS, W2-BUILDSYS | Destroyed or demolished stations and containers never delete contents | spec 10:102, 11:155 |
| W2-GATHER | Rare finds follow the island's climate materials | world-design.md:66-71 |
| W2-BUILDSYS | Chest ~100 slots, large box up to 160 (not 20/40) | PRD:582, spec 05:14, 10:90 |
| ECON | Processed goods keep every per-instance field through escrow and listings | PRD:131, spec 06 |

## Before the next deploy

Play the merged loop in a local web build from a new character at 1600x900 and 844x390 (gather -> rare find ->
craft a better tool -> level a skill -> build) and tell the owner what a new player can do (HANDOFF.md:19).

## Next packages (priority 2, the core loop), in rank order

1. **W2-CRAFT**: material attributes rolled per gathered/butchered instance (spec 04:6-11; the rare-item economy
   depends on them), the craft card with family slots filled by exact picked instances and a level preview
   (spec 11, docs/reference/durango-craft-build-menu.webp), crafting ability and flawless rolls (04:36-38), in-place
   material techniques with trade-offs and limited attempts (11 sections 5-7), metal knives/axes as combat weapons
   with stone/flint/obsidian work variants (PRD:623).
2. **W2-COOK**: spec 08 new-food recipes with slot roles, inheritance flags, topping/broth buffs, digestion.
3. **W2-CAPTURE**: spec 09 capture rule (stunned at any HP or HP <= 30 %, chance from HP/level/ability, ~50 % hint),
   one capture -> cage -> pen -> bond path; carve it out of claude/mmo-w2-breed.
4. **W2-CONSTRUCT**: spec 10 blueprints gated by learned Construction nodes (10:177), building level from materials,
   comfort/rest in a closed house (10:108; PRD:1066 rest building).
5. **W2-SURVIVAL**: spec 01 energy as a slow bar spent by gathering/crafting and refilled by food (PRD:403-404),
   separate from stamina and fatigue.
6. **W3-EXCHANGE**: the Island Market screens (Buy/Sell/My Listings/Sold/Expired/History, fee/tax preview,
   Receive All); with no hosted server, an honest offline harness with simulated buyers (spec 06:21).

The raw reader output was not committed.
