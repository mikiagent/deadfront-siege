# Writable storage and fresh training, October 7

## Storage

Basket/pet storage UI previously offered taking only. Bag buttons selected but could not deposit. Add selected-item Store for explicitly writable basket/pet storage. Corpse/default storage remains take-only. Read-only, locked, equipped and quick-food items cannot be stored. Transfer keeps quality/attributes and leaves rejected remainder in the original slot; full destination changes nothing. No capacity increase, deletion or price/stat change.

Godot4.7 full suite PASS: whole/partial/full transfers, source preservation, locked/self protection, quality, take-only default, writable basket and equipped/read-only restrictions. Inspected960x600 local before/after pixels: Store button readable at bottom after scrolling; after activating,5thread moves from bag to storage. These are seeded UI fixtures, not earned collection. Existing layout puts actions below fold and clips selected-item details. No broad layout fix included; pointer tap untested (button signal exercised).

## Fresh bounded run

Fresh0skills, empty20-slot bag, no occupation/items/XP/vital seeds. Real tap/radial gather, player crafting, validated headless paid placement.30simmin at20x clock. Early7rungs complete; survivor walks to its paid/built basket and uses selected-item Store UI for9surplus stacks, freeing bag15->6. No direct inventory deletion or bigger bag.

Later stopped advancing at fatigue recovery: survivor at(1.5,1.818,-24.126) could not reach camp sleep(1.5,1.084,6.5),30.6m gap, nav false after deadline. Last useful gathering/crafting around9min. End1801simsec: Survival11/Gathering6/Processing3/WeaponTools3/Tailoring2,0deaths. Not55training, not normal-speed/pointer/pixel proof of the journey, no earned raid clear. Rest navigation needs isolated reproduction before a fix. Full regression and storage fixture do not close that blocker.
