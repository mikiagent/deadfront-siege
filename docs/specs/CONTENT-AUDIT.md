# DEADFRONT | Actual item and recipe dependency audit

**Reviewed on:** 2026-10-26 from GitHub branch `docs/deadfront-technical-blueprint-2026-10-26` at `game/data/items.json` and `game/data/recipes.json`. **No source gameplay files edited.**

## Count summary

- Current item definition catalog: **153 items**.
- Current recipe catalog: **73 recipes**.
- Proposed defining weapons: **18**, as six combat classes × three eras.
- Weapon outputs **already defined as items**: **5**.
- Weapon outputs with **missing item definitions**: **13**.
- Weapon outputs without exact existing recipe output: **14** (must not be automatically marked build-ready).

## Existing weapon output IDs

- `slingshot` (early DI), exact existing recipe output: yes
- `stone_knife` (early DS), exact existing recipe output: no / requires explicit check or new recipe
- `bone_hammer` (early MI), exact existing recipe output: yes
- `work_axe` (early MS), exact existing recipe output: yes
- `raid_maul` (late MI), exact existing recipe output: yes

## Missing weapon item IDs

- `sinew_shortbow` (early DP)
- `bone_spear` (early MP)
- `scute_staff_sling` (mid DI)
- `copper_crossbow` (mid DP)
- `talon_whip` (mid DS)
- `scute_warhammer` (mid MI)
- `talon_war_lance` (mid MP)
- `obsidian_great_axe` (mid MS)
- `iron_stonecaster` (late DI)
- `iron_repeating_crossbow` (late DP)
- `iron_talon_whip` (late DS)
- `iron_war_lance` (late MP)
- `iron_talon_greatblade` (late MS)

## Named missing ingredient/component item definitions

- `carved_bone_rib`
- `sinew_cord`
- `braided_sinew_cable`
- `copper_trigger_assembly`
- `cured_hide_binding`
- `honed_talon_set`
- `forged_iron_fittings`
- `reinforced_stock`
- `reinforced_bone_block`
- `iron_trigger_mechanism`
- `iron_bolt_magazine`
- `iron_chain_links`
- `reinforced_haft`
- `forged_maul_head`
- `forged_spearhead`
- `long_lance_shaft`
- `forged_greatblade`

Also unresolved in proposed matrix: `lashing` and `twine_or_bark_strip_or_root` are **alternative ingredient category descriptions**, not literal `items.json` IDs. The authoritative recipe system must express `any_of` predicates for real live IDs. Do not add false literal items called "lashing" solely to satisfy a string.

## Notable blockers

- Late forged weapons depend on actual Forge and Smelter stages, iron input, refined bars, shaped heads, composite stock and manufacturing time.
- `iron_ore` is not currently a declared item ID in `items.json`; `black_iron` is present, but treating it as equivalent needs explicit owner approval and source rules.
- `raid_maul` has an existing item identity, but its future Scute-Core Iron Siege Maul recipe is a proposed **upgrade/replacement**, not proof that the old recipe already meets the new manufacturing standard.
- `stone_knife` is an existing distinct weapon item, while an existing improvised knife recipe outputs `stone_knife_work`; final combat knife recipe needs a correct explicit output rather than conflating these two IDs.
- Existing recipe output presence does **not** demonstrate all physical components, ammo, skills, stations, worked lot inheritance or animations are implemented.

## Required Claude implementation steps after approval

Implement missing material source nodes/defs, then process intermediates, then valid station recipes/required skills, then weapon definitions, ammo and move geometry. Add tests checking every weapon has resolvable ingredient sources, station, ammo supply and actual equipment-level gate. Block shipping when a required ingredient has no source and when category placeholder names are treated as item IDs.

**Caveat:** This is a static catalog cross-check, not an in-engine runtime build or a complete proof of item reachability through island travel/skills. All numeric recipe counts in chapter 23 remain proposals pending owner approval.
