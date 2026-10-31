# PEN-DIET design review (goldfish, round 1, 2026-10-30)

Fresh read-only subagent, no conversation history; target `pen-diet.md`. It also saw that code
had started in the working tree (the brief and the first code went in together in this pilot;
next time the review runs before any code).

| # | Sev | Problem class | Finding | Resolution |
|---|---|---|---|---|
| 1 | Major | brief contradicts cited code | "bag order" vs `FieldTame.food_in_bag` iterating the diet list | Brief fixed: diet list order |
| 2 | Major | tests that cannot fail | Idle/empty pen, spoiled food, carnivore-refuses-berries, save round trip already pass on base | Marked as regression guards; "fails on base" limited to the new behaviour |
| 3 | Major | UI contradicts data | Compsognathus eats berries but the pen diet tile says Carnivore (swarm archetype) | Known gap, out of scope; in report and brief |
| 4 | Major | stale current doc not owned | `docs/current/ui-screens.md` says "Feed meat" | Owned and updated |
| 5 | Major | parallel system | Second food picker beside FieldTame's | Shared `FieldTame.diet_food_in_bag(inv, def)`; pen skips the capture lock (`# ASSUMPTION`) |
| 6 | Nit | tuning not in register | x0.8 default | Open Questions P7 |
| 7 | Nit | latent bug kept | 5 s floor lengthens a nearly finished wait | Fixed with `minf`, tested |
| 8 | Nit | HUMAN item has no pass rule | | Exact refusal string asserted; human pass rule written |
| 9 | Nit | approval scope | Milan approved the work, not the x0.8 number | Agreed: stays an `# ASSUMPTION` in P7 |

Round 1 closed: no Blockers, all Majors resolved.
