# 23. Target selection and the pet radial (owner, 2026-10-20)

Owner's words, verbatim: "You can tap on an animal, that selects it, if you press red swords you initiate combat with it. Pet radial menu to mount and ride, etc"

References: `docs/reference/durango-target-select.webp`, `docs/reference/durango-pet-radial.webp`. The rest of this file is the orchestrator's reading.

## Target select (first shot)

- A wild Stegosaurus is selected. A top-centre target plate shows the name with its level in red ("Estegossauro Nvl. 20"), a portrait at the right end, and a red HP bar "2689 / 2689".
- A dark hex with a red X / crossed-swords icon floats beside the animal, with a keyboard hint "E". Tapping it starts combat.
- Tapping only selects. There is no attack until the swords are pressed.

## HUD details visible in the same shots

- **Level badge:** a round "39 LEVEL" badge at the top left, next to segmented HP and stamina bars and two status chips.
- **Skill hexes, bottom right:** "1" is a target/capture hex with a red X, "2" is a ride hex, and empty slots follow.
- **Left-edge column:** search, chat, emote and menu.
- **Bottom-left:** a pet switcher "R".

## Pet radial (second shot)

- Tapping your own tamed pet (a Zebraceratops named "REX") opens a dark ring of 6 segments around a centre disc. The centre shows the pet's portrait and name, a yellow arc (a meter) and a "[F2]" hint.
- Each segment has a white icon and a label outside the ring:
  - Animals menu (Menu de Animais)
  - Bag (Bolsa: the pet's cargo)
  - Feed (Alimentar)
  - Ride (Cavalgar)
  - Dismiss / send home (Dispensar)
  - Rename (Alterar Nome)

## Where this sits

- Specs 02 and 07 cover companions, combat and stances.
- The STATUS owner decision of 2026-10-18 is "keep tap-target auto-attack AND add an action mode". The owner's new description (tap selects, the swords start combat) is newer. The packages check spec 07 and reconcile the two (see STATUS).
