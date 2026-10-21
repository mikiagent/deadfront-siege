# 19. Character creation screen (owner, 2026-10-20)

Owner's words, verbatim: "This is what the player creation page looks like"

Reference: `docs/reference/durango-character-creation.png`. The rest of this file is the orchestrator's reading.

- **Header:** "Gender/Profession" on the dark torn-edge band, the same chrome as specs 13 and 14.
- **Left column:** a list of occupations (Engineer, Office Worker, Student, Farmer, Attendant, Soldier, Homemaker, Job Seeker) separated by dotted lines. The selected one sits on a lighter row with yellow corner brackets.
- **Centre:** the occupation's name as a large gold title ("Soldier"), and a full-body 3D survivor standing on a dark stage, in an outfit that fits the occupation.
- **Bottom left of the centre:**
  - the starting skill in gold, "Lv. 20 Melee";
  - a short story line in white: "Gained both incredible reflexes and sleepless nights as a result of real-life combat experience."
- **Bottom bar:** a gold hex gender toggle (♂, labelled "Male") on the left and a yellow "Next" button on the right.

What binds it:
- PRD §5.1 (docs/prd/durango-wild-lands-systems-prd.md:326-340): "8 occupations × 2 genders = 16 authored faces/stories". An occupation is not a class lock, and each one starts at skill proficiency 20 in one tree. No occupation starts in Survival, Processing, Butchering or Ranged.

Already in the base:
- `game/data/skills/occupations.json` has the eight occupations (id, name, tree, story).
- `game/scripts/ui/character_creation.gd` handles occupation, gender and name, and World/SaveGame apply and save the occupation.
- The only survivor model is a woman (`game/data/characters/survivor.json`). A male survivor is new character art, which needs a concept sheet approved by the owner before any Tripo spend.

## Step 2: Create Character (owner, same day)

Owner's words, verbatim: "You can choose the size and profile pic, 3D model"

Reference: `docs/reference/durango-create-character.png`. The rest of this section is the orchestrator's reading.

- **Header:** "Create Character" with a back arrow.
- **Left column:**
  - The current portrait, framed with yellow corner brackets.
  - Tabs: Portrait (selected), Appearance and Color.
  - A dice button (randomise) at the bottom.
- **Sub-tab hexes for Portrait:** Portrait (selected, gold), Pattern and Background Color.
- **Centre:** the live 3D model in underwear on a dark stage.
- **Right panel:**
  - A column of clothing toggles (three shirt icons, one selected with a dotted ring).
  - A vertical size slider between a small and a tall figure icon.
  - A grid of 15 painted face portraits, the selected one with a gold border and a check.
  - A yellow "Next" button.
- **Our gaps:**
  - We have no painted portrait art. A painted set is new art, and the owner chooses its source.
  - Our only survivor model is female, and the owner has not yet answered whether to make a male one.

## Appearance list, Color tab and Name step (owner, same day)

Owner's words, verbatim, in order: "height, hairstyles, skin color, facial hair/features", "outfit color", "enter name". The last two came with screenshots that were not saved to disk. The rest of this section is the orchestrator's reading of them.

- **Color tab.** Swatches down the left: Skin Color, Outfit Color 1, Outfit Color 2, Outfit Color 3 (selected in a gold hex outline), Eye Color and Lip Color. On the right is a grid of hex colour swatches in rows of greys, browns, oranges, reds, pinks and purples, the chosen one with a gold border and a check. The model wears a hoodie and trousers whose colours follow the outfit slots. The column of clothing toggles, the size slider, Next and the randomise die are as in step 2.
- **Name step.** A "Name" header with a back arrow. The live 3D model is on the left half; the right half has "Enter the character's name.", a wide grey text field, a ? help line "Can use up to 20 characters, including spaces and special characters such as - and .", and a yellow OK button.
- **Split of the work.**
  - CHARCREATE builds height, the colour slots (through texture masks), the Name step, and data-driven slots for hairstyle, facial hair and facial features.
  - CHAR-APPEARANCE (a plan only, no spend) works out the art for those slots and for a male base model. The plan ends in a concept brief for the owner to approve.
