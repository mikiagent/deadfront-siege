# dsc — wave-1 minor findings (in progress)

One line per finding. "fixed" names the file and line; "skipped" names the reason.

1. fixed — `game/scripts/world/placed_building.gd:40` (gate_open uses `== true`)
2. pending
3. pending
4. pending
5. pending
6. pending
7. fixed — `game/scripts/creatures/creature_genetics.gd:104` (`_table()` type guard)
8. pending
9. fixed — `game/scripts/pets/pet_record.gd:209` (origin whitelist, uid format, name/tamed_at caps, wild_level <= level); roster-level uid dedupe deferred to W2-INT by design
10. pending
11. pending
12. pending
13. fixed — `game/scripts/items/item_stack.gd:227` (uid format, created_at clamp)
14. fixed — `game/scripts/items/item_stack.gd:90` (`remint_uid`) + `game/scripts/items/inventory.gd:184`
15. pending
16. fixed — `game/scripts/pets/pet_record.gd:100` (unknown species neutralises stats)
17. fixed — `game/scripts/pets/pet_record.gd:203` (see 9; duplicate-uid hook left to W2-INT)
18. pending
19. pending
20. pending
21. pending
22. pending
23. pending
24. pending
25. pending
26. pending
27. fixed — `game/scripts/creatures/creature_genetics.gd:104`
28. pending
29. pending
30. pending
31. pending
32. pending
33. pending
34. pending
35. pending
36. pending
37. pending
38. pending
