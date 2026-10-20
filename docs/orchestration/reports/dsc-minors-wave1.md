# dsc — wave-1 minor findings (in progress)

One line per finding. "fixed" names the file and line; "skipped" names the reason.

1. fixed — `game/scripts/world/placed_building.gd:40` (gate_open uses `== true`)
2. fixed — `game/scripts/dev/siege_probe.gd:35` (max_hp forced to 250 before the label check; wrong label quits 1)
3. pending
4. fixed — `game/scripts/world/build_placer.gd:229` (a field packs its floor(fertilizer_overflow) back as fruit_fertilizer) + `game/tests/t_build.gd` field-overflow and pen cases
5. fixed — `game/scripts/world/build_placer.gd:219` (packed kits carry flag `repacked`; `_take_kit` remembers it and place skips the +8 construction / +30 pioneer XP)
6. pending
7. fixed — `game/scripts/creatures/creature_genetics.gd:104` (`_table()` type guard)
8. fixed — `game/scripts/world/taming_pen.gd:76` (legacy bond notices, then falls through to the captured_animal insert; stays put only at the bonded cap)
9. fixed — `game/scripts/pets/pet_record.gd:209` (origin whitelist, uid format, name/tamed_at caps, wild_level <= level); roster-level uid dedupe deferred to W2-INT by design
10. pending
11. pending
12. fixed — `game/scripts/dev/siege_probe.gd:35` (max_hp forced to 250 before the label check; wrong label quits 1)
13. fixed — `game/scripts/items/item_stack.gd:227` (uid format, created_at clamp)
14. fixed — `game/scripts/items/item_stack.gd:90` (`remint_uid`) + `game/scripts/items/inventory.gd:184`
15. fixed — `game/scripts/world/build_placer.gd:219` (packed kits carry flag `repacked`; `_take_kit` remembers it and place skips the +8 construction / +30 pioneer XP)
16. fixed — `game/scripts/pets/pet_record.gd:100` (unknown species neutralises stats)
17. fixed — `game/scripts/pets/pet_record.gd:203` (see 9; duplicate-uid hook left to W2-INT)
18. fixed — `game/scripts/world/taming_pen.gd:76` (legacy bond notices, then falls through to the captured_animal insert; stays put only at the bonded cap)
19. pending
20. pending
21. pending
22. fixed — `game/scripts/dev/siege_probe.gd:35` (max_hp forced to 250 before the label check; wrong label quits 1)
23. pending
24. fixed — `game/scripts/world/build_placer.gd:229` (a field packs its floor(fertilizer_overflow) back as fruit_fertilizer) + `game/tests/t_build.gd` field-overflow and pen cases
25. fixed — `game/scripts/world/build_placer.gd:219` (packed kits carry flag `repacked`; `_take_kit` remembers it and place skips the +8 construction / +30 pioneer XP)
26. fixed — `game/scripts/world/taming_pen.gd:127` (species missing from data: print, keep the occupant, leave the pen waiting)
27. fixed — `game/scripts/creatures/creature_genetics.gd:104`
28. fixed — `game/scripts/world/taming_pen.gd:76` (legacy bond notices, then falls through to the captured_animal insert; stays put only at the bonded cap)
29. pending
30. pending
31. pending
32. fixed — `game/scripts/dev/siege_probe.gd:35` (max_hp forced to 250 before the label check; wrong label quits 1)
33. pending
34. fixed — `game/scripts/world/build_placer.gd:229` (a field packs its floor(fertilizer_overflow) back as fruit_fertilizer) + `game/tests/t_build.gd` field-overflow and pen cases
35. fixed — `game/scripts/world/build_placer.gd:219` (packed kits carry flag `repacked`; `_take_kit` remembers it and place skips the +8 construction / +30 pioneer XP)
36. pending
37. pending
38. fixed — `game/scripts/world/taming_pen.gd:76` (legacy bond notices, then falls through to the captured_animal insert; stays put only at the bonded cap)
