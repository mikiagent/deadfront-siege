# Progression arc, October 6

## Route decisions

14 outbound islands from the existing catalogue, displayed in a scrollable harbour sheet.
Tier15 unlocks at Survival10, tier20 at15, tier25 at20, tier30 at25,
tier35 at30, tier40 at35, tier45 at40, tier50 at45, tier55 at50, volcano60 at55.
This preserves trees.json's five explicit Survival milestones. No extra SP purchase.
Unstable Temperate remains the same 5T route but now requires Survival20.
All other missing catalogue costs default to 5T; return home remains free.
Gate checks live in World as well as the buttons. No charge for a locked route.
Voyage records and victory persist with backward-compatible absent-field defaults.
Old objectives retain their indices; the new orders append after first sail.
Orders guide a canonical route through tiers30/35/40/45/50/55/60; same-tier alternatives
remain optional. Final objective is a player/pet-attributed T-rex kill on volcanic60.

Survival previously gained only 1XP/minute plus 5XP/travel. Reaching Survival55 by the
clock alone takes about 216.3 hours (sum 20+8L for L0..54 is 12980XP).
Survival now mirrors non-Survival skill gains, matching its existing "any play" definition.
Mirrored gains do not award duplicate Pioneer XP; clock/travel Survival gains still do.
This is a pacing change requiring fresh earned-play soak testing, not a measured pace claim.

## Evidence

Godot4.7-stable regression suite PASS. Godot4.5 is too old for current animation APIs.
Fresh-state probe: all 14 routes checked below/at threshold, real harbour callbacks,
5T debits, free returns, voyage state, wrong-island/unattributed boss rejection,
victory condition and save/reload. Proficiency and coins seeded: PARTIAL, not earned play.
960x540 local rendered harbour inspected: scrolling, enabled routes, disabled thresholds,
heading and close button readable. This is local pixels, not production or pointer play.

## Combat baseline before gate edits

Run tools/raid_combat_audit.py. Current T-rex stays 200000HP/1100ATK/400DEF.
At L60 weapon + Melee60, behind with no interruptions: club ~447.6min expected TTK;
stone combat knife ~466.2min. One noncrit contact does1090 damage against100HP.
A fair solo raid is unsupported. The damage floor means not literally zero damage;
perfect evasion or coordinated pets have not been proved feasible.
For a five-minute behind fight at1Hz, neutral weapon needs >=475.71 actual damage.
Armor was not read by CreatureAttack and no catalogue item supplied armor_value.
Gear is a separate patch, not a boss retune. No production deploy.
