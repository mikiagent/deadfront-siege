# GATHERFIX: gather radial and node labels hold still (CONTROLS B1, extracted)

Owner: "fix the resource gathering ui glitch" (first reported 2026-10-20: "UI glitching up and down on resource nodes when clicking around").
This is CONTROLS phase B1 only (branch claude/mmo-controls commits 34a1e43e, 6adc4b55, 98ba8b0d; cause, design and numbers in
docs/orchestration/reports/claude-mmo-controls.md section B1), taken onto claude/mmo-overhaul without B2-B4.

What the player gets: the gather radial solves its layout when it opens and then moves with its node (RadialHold); the camera
is no longer physics-interpolated (it follows in _process), so screen UI no longer drifts against the plant; node label pills
keep a stable order and glide instead of hopping rows.

Gates on claude/mmo-overhaul 7944ccd8 + B1: all 26 t_*.gd PASS (incl. "[t_controls] PASS"; t_save 5 deliberate SCRIPT ERRORs),
run_all "[tests] PASS", "SMOKE PASS". gather_jitter_lab 1600x900 gl_compatibility: walk 0 px; click max 45.62 px in 2 frames
(one camera step while clicking between nodes) vs 136-140 px and ~100 frames over 2 px before B1.

Known, left for a follow-up: (1) that one 45 px step when clicking between nodes at 1600x900; (2) on phones a held radial that
lags its node by 64 px re-solves in one 155 px jump (B1 report) - glide the re-solve and let a held label change side on its own;
(3) the B1 jitter lab cannot find a node on screen at 844x390 on today's base (CONTROLS B3 fixed the lab's phone set-up).
