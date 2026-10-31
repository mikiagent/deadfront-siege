# 27. Painted 2D asset sheets and glowing eyes (owner, 2026-10-21)

Owner's words, verbatim: "2D asset concepts, green screen for isolation, shared art style," and "we want to give some of the
dinos glowing eyes (especially in the dark)".

## Sheets (docs/reference/2d-assets/, pure green #00FF00-ish background for chroma keying)
- `sheet-resources.webp`: a crystal cluster on rock (ore node), a mossy boulder pile, a dirt/clay mound, a mossy fallen log,
  a pile of cut logs, a bamboo bundle; broadleaf plant, red-flowered plant, white-flowered herb; two mushroom clumps (red
  amanita, blue); fruit bunches (red berries, bananas), coconuts, a cacao-like pod and spiky chestnuts; bones and a tooth;
  seashells; oyster/rock shells.
- `sheet-jungle-plants.webp`: ferns and cycads, broadleaf and red-flowered plants, hanging vines, ivy mounds, papyrus, reeds and
  tall grass, fallen-log tangles with roots, single leaves and fronds.
- `sheet-palms.webp`: coconut palms (large, tall, leaning, cluster, young), palm crowns from above, fronds, a fallen trunk, a
  broken stump, a root ball, coconut bunches.
- `sheet-beach-shells.webp`: clams and scallops, shell scatters, shell-and-seaweed piles with driftwood, coral rock.

## How they are used (orchestrator's reading)
- They are the art for the 2D cards (owner: resources and props "2D but realistic and kind of look 3D"; buildings stay 3D):
  cut each item out by chroma key into a trimmed PNG with alpha (green spill removed), pivot at the ground point, then map it to
  a resource family or a prop kind. Painted art replaces the cards baked from 3D models where a match exists (the baked small
  plants came out dark).
- Items like fruit, bones, teeth and shells also suit bag icons later (not part of this pass).

## Glowing eyes
Some species get eyeshine: two small emissive points on the head that are faint by day and glow at night (scaled by the world's
night factor), coloured per species in data (ASSUMPTION: predators and nocturnal species first; a rare colour morph may get a
different eye colour). It must stay attached to the head through every clip and never show through the body.
