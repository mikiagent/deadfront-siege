<!-- Owner's prompt, pasted 2026-10-20 with three screenshots. Local copies of the references:
     docs/reference/durango-bag-instances.webp (bag, 2000x1139; a smaller copy is durango-bag-caged-animal.webp),
     docs/reference/durango-character-gear.webp (Character -> Gear, 2000x1129),
     docs/reference/durango-equipment-myinfo.webp (Equipment / My Info, 1942x1070).
     The text below is verbatim. -->

Claude Implementation Prompt: Recreate Durango: Wild Lands Inventory UI
Objective
Recreate the original 2019 Durango: Wild Lands inventory and equipment interface as faithfully as possible within my existing game.
This is primarily a visual UI/UX implementation task, not a request to rebuild the inventory backend.
Use the existing inventory system, item instances, equipment, material attributes, crafting, storage, and marketplace functionality.
The new interface should look and behave like Durango's original mobile inventory, not a generic fantasy RPG inventory.
Prioritize:

1. Authentic screen proportions and panel layout.
2. Earthy prehistoric UI textures and colors.
3. Dense inventory grid with individually selectable items.
4. Small item-level labels and NEW indicators.
5. Yellow selection brackets.
6. Context-sensitive item inspection panels.
7. Character equipment and gear loadouts.
8. Actual working inventory interactions.

1. Original Visual References
Use these original screenshots as primary references.
Bag inventory screenshot:
https://cdn-www.bluestacks.com/bs-images/Durango_Taming_EN_10.jpg
Character and equipment screenshot:
https://cdn-www.bluestacks.com/bs-images/Durango_Survival-Basics_EN_11.jpg
Equipment details screenshot:
https://img.utdstc.com/screen/e43/746/e437460ec2fca755e4a1dbf99d4908615a7e4f93de2b55fd42b857fb95548225%3A600
Study these screenshots carefully before implementing the UI. Do not assume that every original interface element is visible in these references.
2. Overall UI Style
The interface should resemble rugged, survival-themed equipment management rather than a polished sci-fi or conventional fantasy menu.
Primary colors
Use these approximate reference colors:

* Main background: `#101714`
* Inventory panel: `#39392F`
* Secondary panel: `#26322C`
* Slot separators: `#56534A`
* Selected item highlighting: `#E6BE54`
* Primary button: `#F2C84C`
* Main text: `#ECEBE4`
* Secondary text: `#A6A69B`
* Disabled text: `#77786F`
* NEW label background: `#176897`
* Positive material properties: muted yellow/gold
* Negative material properties: gray
* Rare material properties: green

These are approximate design values, not official game color codes.
Textures
Use subtle textures resembling:

* Weathered wood
* Worn canvas
* Aged leather
* Scratched metal
* Rough stone
* Dirty brown and olive surfaces

Keep the textures subtle enough that item icons and text remain readable.
Borders
Use dark, slightly irregular panel borders.
Avoid bright white outlines, heavy modern shadows, glassmorphism, neon accents, and oversized rounded cards.
The original interface looked functional, compact, and somewhat industrial.
3. Landscape Screen Layout
Design for a landscape mobile viewport.
Reference aspect ratio: 16:9.
The interface should fill almost the entire visible screen.
Screen regions
Top navigation bar: Approximately 8–10% of screen height.
Main inventory area: Approximately 78–82%.
Bottom toolbar: Approximately 10–12%.
These are approximate proportions.
Use responsive scaling rather than assuming a single device resolution.
For desktop builds, retain the landscape layout and support mouse interaction.
For mobile builds, retain touch-friendly controls without making everything oversized.
4. Bag Screen: Top Header
The original inventory header displays:
`< Bag [bag icon] 91 / 100`
Implement:

* Back arrow on far left.
* Bag title in large, readable white text.
* Small yellow bag icon near the title or capacity.
* Occupied inventory count.
* Maximum inventory capacity.
* Dark header background.
* Minimal decorative elements.

Example
Bag 91 / 100
The capacity must come from actual inventory data.
When equipment changes capacity, the number must update.
Example:
Bag 91 / 142
Do not hardcode 100 if the player has capacity bonuses.
Full Inventory State
When the inventory reaches capacity:

* Change the capacity indicator to a warning color.
* Prevent invalid item pickups.
* Show an appropriate inventory-full message.

5. Bag Screen: Main Inventory Grid
The original screen shows a dense arrangement of item slots.
Grid layout
At the reference screenshot's viewport width, approximately seven inventory columns are visible.
Each slot is:

* Roughly square.
* Compact.
* Separated by thin, faint lines.
* Dark brown or olive.
* Slightly textured.
* Mostly flat, without large raised borders.

Avoid the oversized square tiles commonly seen in modern RPG inventories.
Slot background
Use one continuous inventory panel divided by fine grid lines.
Individual slots should feel like compartments within a single inventory surface.
Empty slots remain visible.
They should not disappear when no item is present.
Item icons
Each slot may contain:

* Item sprite centered in the cell.
* Small level label.
* NEW tag.
* Durability or condition indication when relevant.
* Selection highlighting.

Icons should be large enough to recognize but leave room for metadata.
Use actual item sprites from the existing project.
Do not substitute generic placeholder emojis in the finished implementation.
6. Item Level Labels
Original Durango inventory slots commonly displayed a small level label near the bottom.
Examples:
`Lv. 10`
`Lv. 45`
`Lv. 60`
The text was understated, usually gray or muted white.
Requirements

* Position level labels consistently.
* Keep them small but readable.
* Use actual item-instance levels.
* Do not display an irrelevant level on items that have none.
* Do not overwrite rare-property indicators.
* Support levels up to the project's configured maximum.

A Level 60 Bone and Level 45 Bone must remain distinguishable.
7. NEW Item Indicators
One especially distinctive feature of the original Bag UI was the blue NEW label.
Freshly acquired items displayed small blue rectangular tags.
Requirements

* Blue rectangular background.
* White uppercase NEW text.
* Small size.
* Positioned near the top-left of the slot.
* No exaggerated animation.
* Must not obscure the central item sprite.

When the player has acknowledged an item according to the game's existing rules, remove the NEW state.
Keep this separate from rarity.
A common item may be NEW.
A rare item may no longer be NEW.
8. Selected Item Highlighting
Durango used bright yellow corner brackets around selected inventory items.
This is one of the most important visual details to reproduce.
Selection appearance
When a slot is selected:

* Four yellow L-shaped corner brackets appear.
* The brackets sit near the cell's corners.
* Their lines are relatively thick.
* The item remains visible.
* A subtle tint may appear behind the selected slot.

Do not use a thick continuous yellow rectangle if you can reproduce the original corner-bracket appearance.
Selection behavior

* Tap or click selects an item.
* Selecting another item moves the brackets.
* Selected item details update.
* Selection remains stable during harmless UI refreshes.
* If the item is removed or transferred, clear or update selection safely.

9. Bottom Inventory Toolbar
The original inventory screenshot includes a dark toolbar at the bottom.
Auto Sort
The left side contains a wide Auto Sort control.
It should look like a dark rectangular button with:

* Light-colored text.
* Subtle border.
* Small adjacent dropdown arrow.
* Minimal corner rounding.

The Auto Sort button must reorganize the presentation of inventory items.
It must not change item properties or merge unique materials.
Right-Side Controls
At the bottom-right, the reference shows three square utility buttons.
Their iconography includes:

* Selection-related control.
* Filter/funnel control.
* Lock-related control.

Implement functioning equivalents appropriate to the existing inventory system.
Sorting
Possible options:

* Name
* Item type
* Item level
* Acquisition time
* Rarity
* Material attributes
* Durability

These extended sorting options are usability improvements beyond what can be confirmed from the reference image.
Filtering
Allow filtering by relevant item categories.
Locking
If the project supports item locking, players should be able to protect valuable items from accidental selling, dropping, processing, or crafting consumption.
Preserve locked state in save data.
10. Detailed Item Inspection
When selecting an item, open or update a contextual item detail panel.
This panel must display the actual properties of the selected item.
Example
Large Leg Bone
Level 60
Material type: Bone
Positive attributes:

* Firm Lv. 8

Negative attributes:

* Low Density Lv. 3

Rare attributes:

* Black Sheen

Processing remaining: 4
Durability: 100 / 100
Visual hierarchy
Use:

* Larger item name.
* Item icon.
* Level near the title.
* Small section labels.
* Colored attribute text.
* Compact information rows.
* A dark background.
* Thin dividers.

Do not use modern oversized cards with excessive padding.
Item Actions
Possible actions:

* Use
* Equip
* Unequip
* Eat
* Process
* Craft With
* Move
* Store
* Drop
* Sell on Market
* Inspect
* Lock

Only show valid actions for the selected item.
Selecting a berry should not expose an Equip Weapon button.
Selecting a weapon should not expose an Eat button.
11. Rare Material Indicators
The original game used material properties that directly affected crafting.
Maintain that behavior.
Attribute colors

* Negative attributes: Gray.
* Positive attributes: Yellow/gold.
* Rare attributes: Green.

These distinctions should appear clearly in item details.
Optional Grid Improvement
To make rare materials easier to recognize, add a subtle green corner mark or glow to slots containing rare attributes.
This is a proposed modern improvement, not a confirmed original slot decoration.
Keep it much less prominent than the yellow selected-slot brackets.
Do not replace individual material properties with generic Common, Rare, Epic, and Legendary tiers.
12. Nonstacking Items
This is essential.
In Durango, ordinary material resources generally occupied separate inventory spaces even when they shared the same name.
For example:

* Wild Berry, Lv. 12
* Wild Berry, Lv. 25
* Wild Berry, Lv. 42, special trait

These must appear as three individually selectable items.
They occupy three inventory slots.
Technical Requirement
The UI must reference unique item-instance IDs.
Do not display all three berries as:
`Wild Berry ×3`
unless the project supports optional visual grouping that can expand back into individual instances.
Never collapse three items into one backend record and lose their traits.
Exact Selection
When the player selects a berry for cooking, the exact instance must be chosen.
When selecting a rare bone for the marketplace, the exact bone must be listed.
Sorting and filtering must never modify these identities.
13. Character Equipment Screen
Recreate the original Character → Gear interface.
Use the second reference screenshot.
Main layout
The equipment screen is divided into two major sections:
Left: Character information
Right: Equipment and loadouts
A dark header at the top contains:

* Back arrow.
* Character title.

Left Panel
Display:

* Character portrait.
* Character name.
* Clan affiliation or status.
* Level.
* Experience progress.
* Combat Power.
* Crafting Power.
* Gathering Power.
* Detailed Stats button.
* Flag or affiliation control if supported.

The screenshot shows the character portrait in a small square at the upper-left of this panel.
To its right are the character name and clan status.
Below is a horizontal green XP bar, followed by several rows of summary statistics.
Use faint horizontal separators.
Detailed Stats
The Detailed Stats button should open another panel containing applicable character attributes.
Examples:

* Attack
* Defense
* Accuracy
* Strength
* Dexterity
* Agility
* Endurance
* Intelligence
* Combat bonuses
* Crafting bonuses
* Survival bonuses

Only display statistics actually supported by the existing game.
14. Equipment Panel
The right side of the Character interface contains equipment management.
Upper Tabs
Use tabs such as:
Gear | Decorative Gear
The active tab should be a large muted-yellow rectangle with dark text.
Inactive tabs should be dark.
Gear Presets
Below the Gear tab are numbered equipment loadouts.
The reference includes:

* Preset 1
* Preset 2
* Locked preset indicator

Use compact rectangular selectors.
Highlight the active preset with yellow corner brackets or an appropriate selected state.
Do not introduce unlocked loadouts that the player has not earned.
Equipment Slots
Use a compact grid with dark item cells.
Support equipment types already present in the project, such as:

* Headwear
* Torso
* Gloves
* Footwear
* Primary weapon
* Secondary weapon
* Accessories
* Other existing equipment categories

Empty slots should contain faded silhouette icons rather than appearing completely blank.
Equipped items should show their real sprites and relevant level or durability data.
Selected Gear
Selecting a piece of equipment should highlight its slot using yellow corner brackets.
An item detail interface should provide its properties and an Unequip action.
Gear Changes
Equipping or unequipping items must update:

* Character attributes
* Combat statistics
* Crafting Ability
* Environmental resistance
* Inventory capacity
* Relevant equipment abilities

Do not apply bonuses twice.
15. Equipment Selection and Stats
The third screenshot shows an equipment-management panel with a section labeled My Info.
It includes three important summary statistics:

* Attack
* Defense
* Accuracy

These appear as three adjacent columns with icons and numeric values.
Below them is a row of hexagonal action or ability icons.
Recreate this layout where applicable.
Equipment Comparison
When selecting replacement gear, show:

* Current item.
* Candidate item.
* Relevant stat differences.
* Positive improvements.
* Negative trade-offs.
* Equipment requirements.
* Equip action.

Only show meaningful comparisons for the selected equipment type.
16. Inventory and Equipment Transitions
Switching between Bag and Character equipment should feel like moving between sections of the same unified game interface.
Use:

* Consistent top bars.
* Shared fonts.
* Same yellow highlight language.
* Same panel textures.
* Same item icons.
* Same item inspection conventions.
* Similar button sizing.

Do not give the Bag screen a fantasy interface and the Character screen a completely unrelated modern design.
17. Storage and Dinosaur Cargo UI
Use the Bag grid as the shared visual foundation for other inventories.
Storage Box
When interacting with a container, show the player's Bag and the container inventory in a suitable split or switchable layout.
Dinosaur Cargo
When interacting with a bonded dinosaur, show its cargo inventory using the same slot design.
Shared Rules

* Individual item slots.
* Level labels.
* Selected-slot brackets.
* Exact instance selection.
* Storage capacity.
* Filters.
* Valid transfer actions.

Each inventory must remain independently tracked.
18. Marketplace Integration
From the selected item details, support Sell on Market.
Selecting this action should open the existing marketplace Sell screen with the selected item already populated.
Preserve the selected item ID.
The marketplace should show the same icon, level, durability, and attributes displayed in the Bag.
Do not recalculate or regenerate item properties.
19. Cooking and Crafting Integration
The Bag interface must allow exact material selection.
Example
Player opens a cooking recipe requiring three berries.
The ingredient selector opens a filtered inventory view.
The player sees:

* Berry Lv. 12
* Berry Lv. 25
* Berry Lv. 42 with special trait

The player must be able to choose exactly which berry will be used.
Use the same slot icons, selected-item brackets, and attribute descriptions throughout crafting and cooking interfaces.
Do not automatically consume the most valuable item.
20. Interaction and Animation
The original interface was compact and responsive.
Use restrained transitions:

* Quick panel opening.
* Short tab switches.
* Subtle selection feedback.
* Minimal button feedback.
* Smooth scrolling.
* Small item transfer feedback.

Avoid long animated screen transitions, excessive particle effects, and large bounce animations.
The interface should feel responsive under repeated use.
21. Responsive UI Requirements
Support mobile landscape and desktop layouts.
Mobile

* Touch-friendly tap targets.
* Readable item metadata.
* Scrollable inventory.
* No overlapping buttons.
* Appropriate safe-area margins.
* Efficient one-tap item inspection.

Desktop

* Mouse selection.
* Scroll wheel navigation.
* Keyboard shortcuts where existing project conventions support them.
* Tooltips where appropriate.

Keep the original Durango look rather than redesigning the interface separately for desktop.
22. Architecture Requirements
Before writing code:

1. Inspect the existing UI framework.
2. Find current inventory interfaces.
3. Find equipment interfaces.
4. Find item definitions and instance data.
5. Find material attribute displays.
6. Find selection and transfer logic.
7. Find sorting and filtering.
8. Find save/load support.

Implement reusable UI elements:

* Inventory grid.
* Inventory slot.
* Item icon.
* Level label.
* NEW indicator.
* Selection brackets.
* Rare-attribute marker.
* Item inspection panel.
* Bottom toolbar.
* Equipment slot.
* Gear preset selector.
* Inventory capacity indicator.

Follow the project's established component or scene architecture.
Keep UI presentation separate from authoritative inventory state.
23. Testing
Verify the following:

1. Opening and closing the Bag.
2. Correct inventory capacity display.
3. Individually displayed resources.
4. Proper item levels.
5. NEW indicators.
6. Yellow selection brackets.
7. Item inspection.
8. Positive, negative, and rare properties.
9. Sorting.
10. Filtering.
11. Item locking.
12. Item transfers.
13. Equipment changes.
14. Correct stat updates.
15. Gear preset selection.
16. Rare bone selection for crafting.
17. Individual berry selection for cooking.
18. Selling an exact item from inventory.
19. Save/load preservation of selection-independent item data.
20. Correct operation on different screen sizes.

24. Implementation Priorities
Implement in this order:
Phase 1: Bag UI

* Screen layout
* Item grid
* Icons
* Item levels
* Capacity
* Selection brackets
* Bottom toolbar

Phase 2: Item Inspection

* Item details
* Attribute colors
* Rare properties
* Contextual actions

Phase 3: Equipment

* Character panel
* Gear tabs
* Equipment slots
* Gear presets
* Detailed Stats

Phase 4: Integration

* Storage
* Dinosaur cargo
* Crafting
* Cooking
* Marketplace

Phase 5: Polish

* Textures
* Responsive layouts
* Animations
* Accessibility
* Performance

25. Final Acceptance Criteria
The finished UI should immediately resemble Durango: Wild Lands to someone who played the original game.
The most recognizable details should be:

* Dark earthy inventory background.
* Dense seven-column-style inventory grid at reference proportions.
* Small gray item levels.
* Blue NEW tags.
* Bright yellow corner selection brackets.
* Wide Auto Sort button at the bottom.
* Compact bottom-right utility controls.
* Bag capacity at the top.
* Dark character information panel.
* Yellow active Gear tab.
* Numbered equipment presets.
* Equipment silhouette slots.
* Detailed Stats button.
* Consistent individual-item inspection.

Do not replace Durango's aesthetic with a generic modern inventory system.
The inventory must remain functional and connected to the actual unique-item backend.
The final result must preserve the original design's density, visual hierarchy, and survival-game identity.
Final Deliverables
Implement the UI directly in the existing game and report:

1. Files created or modified.
2. Screens implemented.
3. Components reused.
4. Inventory interactions connected.
5. Equipment interactions connected.
6. Item properties displayed.
7. Responsive behavior.
8. Tests completed.
9. Remaining limitations.

When possible, capture screenshots of the implemented Bag and Character equipment screens and compare them side by side with the original references.
Prioritize visual fidelity and functional completeness together.
Do not stop at design descriptions or mockups. Build the working interface in the current project.

<!-- Addendum, 2026-10-20. Owner's words, verbatim: "Another example of the inventory menu". Reference:
     docs/reference/durango-storage-transfer.webp. Orchestrator's reading follows.
     - Storage view: tabs "Bag 61 / 200" and "Small Box 75 / 80". The active tab is gold.
     - Header "1 Select": a multi-select mode that counts the selected items, and a selected item shows a gold check.
     - A left column of category filter icons (all, tools, leaves, knives, ...).
     - Grid cells show "Lv. 60" at the top right, and small gold/grey pips under the icon.
     - A grey tooltip over someone else's box: "this box belongs to someone else - cannot take".
     - Right panel: a gold title band "Iron Ore", the icon and "Lv. 60", durability "100/100", a hammer "x3" for processing count, family chips (Chunk, Iron, Ore, Rock), attribute chips "Firm Lv. 4" in gold and "Heavy Lv. 2" in grey, and an Info section.
     - Toolbar: Auto Sort with a caret, then select-many, select-all, search, lock and trash, plus a yellow "Transfer to Bag" button. -->

<!-- Addendum 2, 2026-10-20. Owner's words, verbatim: "inventory menu while in game, scrollview". Reference:
     docs/reference/durango-bag-ingame-panel.webp. Orchestrator's reading follows.
     - While playing, the bag is a panel docked on the right half, and the live world stays visible on the left.
     - The panel has a "Bolsa" header with back and X buttons, a "Bolsa 186 / 200" tab, a category column, and a vertically
       scrolling 5-column grid of single instances. Each cell shows its Lv., white "+" marks and attribute pips; the
       selected cell has yellow brackets.
     - The item card floats between the world and the bag:
       - a gold title band, the icon and Lv., durability, and the processing count (hammer x2);
       - family chips (Edible / Fragment / Meat) and a processing-state chip ("Raw Lv. 1");
       - Info rows (Satiety, Animal Vigor), a colour hex and a flavour line;
       - Maintenance rows (Repair: not possible), a Create section, and the yellow primary action ("Eat").
     - The toolbar has Auto Sort with a caret, then select-many, filter, lock and trash. -->
