# Durango Capture Health Threshold and Bonded Companion Limits: Implementation Clarifications

Use this as an **addendum** to the existing combat/capture and taming/pets prompts. Do not create a second capture or companion-slot system. Inspect and amend the existing implementation.

## 1. Why 50% health, not a mandatory 30%, is a useful capture target

Contemporary 2019 guides advise fighting the animal to **around 50% HP**, then using a strong stunning attack such as Shoulder Tackle and tapping the net/capture action while stunned. That is a practical player-facing target: it reduces accidental kills and rewards stun-focused weapon choices.

**Critical distinction:** 50% is *not* proven to be a universal hard capture threshold in the original server. One modern server reconstruction documents two ways to qualify for capture:

- Animal HP at or below 30%, OR
- Animal stunned/collapsed at **any** remaining HP.

Thus a valid capture at 50% is possible **because the animal is stunned**, not because a flat 50% rule automatically makes every animal capturable. In the reconstruction, health still influences capture probability, so stunning at 50% is a safer but potentially lower-success option than further weakening to 30%.

**Recommended implementation:**
- Display an early tutorial hint at ~50% HP: 'Stun the dinosaur to capture it safely.'
- Allow capture whenever `stunned_or_collapsed || health_ratio <= 0.30`, subject to species, skill, tool, range, cooldown, and capacity requirements.
- Let players attempt to capture a stunned animal at 50% HP. The capture chance should use actual current HP, level and Capture Ability, rather than substituting 30% HP or granting automatic success.
- Keep health gate, stun rule and probabilities configurable. If the project explicitly prefers simplified arcade taming, it may use a 50% threshold, but label that as a design change rather than original-game fidelity.
- Never force the player to damage an already stunned dinosaur down to 30% just to unlock capture.

Historical guides describe a net-shaped capture UI icon and Shoulder Tackle. A reconstruction describes Taming Herb items, their durability, a 3-second stationary capture bar, 5-second retry cooldown and status checks. Validate applicability by chosen version and avoid mixing all variants as if they are one immutable historical build.

## 2. Capture versus pen taming versus bonding

Keep the three transitions separate:

1. **Capture** wild animal in combat and create an individual captured-animal item/Rein with species, level and traits.
2. **Tame** in a pen over time, potentially using feed to improve timing or success, with a distinct success/failure resolution.
3. **Bond** after successful taming, consuming a bonded-companion capacity slot and turning the animal into an owned companion.

Unbonded captured/tamed animal items must be individually represented in inventory or eligible pens and should not be counted as bonded companions.

## 3. Original-style pet limit progression

Contemporary May 2019 players reported starting with **three bonded pet slots** and increasing capacity through **Survival → Animal Taming → Animal Handling**. The historical community mastersheet records four skill upgrades:

| Skill | Survival level needed | SP cost | Added bonded slots | Total if starting at 3 |
|---|---:|---:|---:|---:|
| Animal Handling I | 35 | 4 | +1 | 4 |
| Animal Handling II | 45 | 5 | +1 | 5 |
| Animal Handling III | 55 | 5 | +1 | 6 |
| Animal Handling IV | 60 | 6 | +1 | 7 |

These are historical community references, not a guarantee that all 2019 regional builds used the same numbers. **Do not use 8 starting slots and +2 each automatically**: those values appear in newer fan-restoration projects and differ from the early documented system.

`bonded_pet_capacity = base_slots (3) + sum(unlocked_Animal_Handling_slot_bonuses)`

The Animal Handling nodes must be real purchases in the Survival skill tree, subject to category level, prerequisites and Skill Points. Display bonded count and max in the pets UI (e.g. `3 / 4`).

## 4. Capacity behavior and training

- Capacity is checked when **forming a bond**, and if the game's chosen rules require it, also before capture; distinguish these checks. Modern restored servers sometimes block capture at capacity, but do not assume this is the same as all historical versions.
- Tamed animals waiting as unbonded items should not consume bonded slots.
- When full, show an understandable error and allow the player to keep the tamed animal unbonded if permitted.
- Animal storage pens and roaming animals require their own capacity and occupancy rules, independent of bonded slots.
- Breaking a bond frees a slot. Original player reports describe a special bond-breaking item, including cash-shop availability; do not build real-money purchases unless the project already uses them and they are requested.
- On skill reset, define predictable behavior if already-bonded animals exceed the new limit. The historical community mastersheet reported that players could temporarily learn all four upgrades, bond the maximum number, then unlearn the skills while retaining those pets. That may be a historical quirk or exploit; for a new robust game, prefer keeping existing pets without deleting them but block *additional* bonding until `count < capacity`. Explicitly document the choice.
- Bonded pets can have distinct species roles, ranks, level progression, cargo inventory and persistent identity; these must survive capacity changes and save/load.

## 5. Test scenarios

1. Stunned dinosaur at 50% HP has a capture action and success is probabilistic.
2. Unstunned dinosaur at 50% HP is not eligible with the 30%-or-stun rule.
3. Unstunned dinosaur at 29% HP becomes eligible.
4. Stunned dinosaur at 80% HP can be eligible, with lower chance based on actual HP.
5. A killed animal cannot be captured.
6. An untameable species and missing capture skill/tool correctly block attempts.
7. Pen-tamed but unbonded animal doesn't consume companion capacity.
8. Initial bond capacity is 3; four Animal Handling upgrades increase it to 4, 5, 6, 7.
9. Each upgrade has the correct Survival level and SP prerequisites.
10. Capacity-full behavior is clear and no creature disappears or duplicates.
11. Resetting Animal Handling skills with more existing bonded pets than new cap never deletes existing pets; new bonding is blocked until valid.
12. Save/load persists skill upgrades, bonded count, ranks and animal inventory.

## Sources and provenance

- 2019 capture guidance around 50% HP and stun: https://www.bluestacks.com/blog/game-guides/durango-wild-lands/first-dino-taming-dinosaur-en.html
- Additional contemporary capture guidance: https://www.touchtapplay.com/durango-wild-lands-guide-how-to-tame-animals/
- Modern reconstructed HP-or-stun rule (not guaranteed original): https://shuuuushi.github.io/Durango-OffServer-Client/en/taming.html
- May 2019 player report on 3 slots and raising Survivor Rank: https://www.reddit.com/r/DurangoWildLands/comments/bqe1u3
- Original community skill-point/Animal Handling listing: https://www.scribd.com/document/501357601/Durango-Wildlands-Mastersheet
- Modern changed skill values (avoid confusing with original): https://kghj76138.github.io/durango-homecoming-guide/en/skills.html

## Final instruction

Apply these changes to the existing game's combat/capture/taming/Survival skill tree systems. Report exactly what was changed, configuration defaults, version assumptions, tests executed, and remaining limitations. Do not replace functional existing systems or build an unrelated parallel implementation.
