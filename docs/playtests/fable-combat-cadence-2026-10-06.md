# Fable handoff: survivor combat cadence

Base202dadad. FABLE-CRITICAL combat-feel finding: damage fires immediately each1/rate
seconds, but survivor heavy clip is1.867s and primary3.033s (old1.5x playback =2.022s).
Each swing restarts the clip. Busy blocks walking and roll. A1Hz auto attack therefore
can keep the survivor in continuous movement lock. Boss primary0.700s impacts at0.294s,
heavy1.350s impacts at0.972s. This invalidates math-only survival assumptions.

Approved narrow rule: ordinary primary/heavy/punch playback is at least
clip_length * max(0.2,weapon.attack_rate) /0.65, so busy animation lasts<=0.65/rate.
Existing faster playback stays faster. No damage, boss stats, roll cost, attack cooldown,
no-walk-during-swing, or skeleton/bind/rest/scale edits. Missing clips retain fallback.

Functional real-time fixture: heavy swing idle after0.7s, normal roll available PASS.
Regression suite PASS. Actual T-rex AI timed-roll fight survived15.9s/7rolls but died;
boss197283HP. This is PARTIAL fight, not a win or proof of fair raid completion.

Visual inspection: raw GLB local reimport renders invisible body; actual live production
pixels show normal survivor. Downloading live imported survivor.scn and using it privately
with unchanged runtime scaling/current animation merge restores normal local pixels.
Do NOT infer2cm production body from0.01 node transform: skin/bind/export behavior matters.
No scaling workaround bundled. Pose sheet using live imported base shows body load,
overhead, follow-through and return to idle0.1-1.0 simulated seconds without collapse.
Local rendering slow (~15x in dense terrain), so real-speed feel remains unverified.
The cadence patch is separate from this unresolved local import parity issue.

Production alias remains ba5a9ed61/59790b80cd, no deploy performed.
