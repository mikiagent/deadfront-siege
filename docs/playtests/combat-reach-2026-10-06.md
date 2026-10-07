# Large-body contact fix

Base95716aa after progression and gear patches. No creature stat/collision retune.
Survivor planar reach=max(2.1, body radius+0.65). T-rex radius2.88 gives3.53m.
Creature reach=max(profile range+0.3, body radius+0.75); T-rex gives3.63m.
Creature approach uses reach-0.1, attack disengage reach+0.1, approach slot reach-0.6.
Small-creature preexisting +0.2/+0.4/-0.3 profile thresholds stay unchanged.
Creature impact now checks planar contact range+0.3 at hit time, preventing a target
who moved out during windup from receiving unlimited-distance damage.

Godot4.7 regression suite PASS. Real-code fresh fixture PASS: survivor strikes3.4m
body edge; boss also strikes it; escaped9m target unharmed. Seeded gear fixture.
A one-sided reach fix was rejected after it let survivor farm from3.05m while boss
could not hit. With mutual reach the timed-roll bot died10.7s,4 rolls, boss199094HP.
Thus PARTIAL: contact geometry fixed, evasive raid not passed. Do not claim beatable.

raid_fight_probe is an honest seeded diagnostic. Real AI, health, physics, attacks,
no immortality/flat damage. Home terrain removes other opponents. Skills/equipment
seeded60 and near-neutral boss genetics. Timed rolls use normal roll input, not hidden
windup signals. This does not test a fresh earned run, volcanic boss spawn, or victory.
