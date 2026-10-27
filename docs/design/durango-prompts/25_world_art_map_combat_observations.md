# 25. World art, map, interaction camera, knife combat, harvesting, skill cap, cooking (owner, 2026-10-21)

Owner's words, verbatim, then the orchestrator's reading of the six screenshots (docs/reference/durango-forest-flat-trees.webp,
durango-knife-combat.webp, durango-corpse-harvest.webp, durango-skill-cap-cooking-quest.webp, durango-craft-skewer.webp,
durango-communication-center.webp).

> I think I'm realizing that a lot of the assets like resources and trees (in Durango Wildlands) are flat 2D models with animations (swaying, rustling, etc). I'm sure this improves the performance of the game and allows you to put more assets in a space. Also the terrain itself (the grass) has different colors for different biomes. It reflects this on the map. There is a parallax effect where the tall trees fade out of zoom. Maybe it's 2.5D where the flat assets go a certain distance z and fade out.
>
> This is interesting/good because it means we can have higher performance and focus our 3D generation on the dinosaur models. We can replace the grassy terrain, trees, etc with 2D assets. I'm willing to try it out and if it looks good and is easy to produce, we should go with that.
>
> For the map, areas that are undiscovered are greyed out and areas that you walk towards are discovered like a paintbrush on a canvas. There are icons on the map for houses(claims), campfires, your footsteps as you walk are registered as black dots from where you came from. Other player icons are grey dots. Certain facilities related to trade, quests, etc, get their own map icons
>
> When you click on a resource or an enemy, the camera pans towards it and the menu pops up (menu stays locked to the resource and doesn't move around)
>
> Jump button, scan button, combat toggle (attack nearest dinosaur?), inventory button and search button are active in the bottom right as you walk around.
>
> Active quests have a bubble and arrow in the direction of the quest (profile picture of the person who gave you the quest)
>
> Combat when wielding a knife is second screenshot: roll is blue and useful for dodging attacks. There is an attack stance in the bottom right that changes how you fight. Tackle and kick button. 2 red buttons are stab and slash. (I think the sword button is basic attack that doesn't consume ) Notice red end combat button.
>
> Something to note, energy seems to always recover even in combat.
>
> Third screenshot is what it looks like to harvest a killed animal. You can loot the body also like any resource. Notice you can't harvest the teeth or leather because you need the right tool.
>
> 4th screenshot, notice bottom left corner it is trying to level up the defense skill but it's full because he needs to level up his character in order to level up defense again. (skill levels are capped to the overall player level). Also it gives you an xp amount.
>
> Cooking a meat skewer asks for the meat and the bone to cook it. There is a success rate and the skewer potentially inherits passives from the ingredients.

## Orchestrator's reading (not the owner's text)

1. **2.5D world art (trial first).** Trees, bushes, ferns and resource props read as painted cards with sway; the ground is a
   painted terrain tinted per biome, and the map shows the same tints. Owner: try it, adopt it if it looks good and is easy to
   produce. Trial: one biome slice (grass ground + 3 tree kinds + 3 bushes + 2 resource props) as camera-facing or crossed
   cards with alpha, sway shader and a height fade near the camera, next to today's 3D set; measure frame time on the web build
   and a phone viewport, blind judge vs today, and the cost to produce one new card. 3D generation then focuses on creatures.
2. **Map (extends spec 15).** Undiscovered area grey; walking reveals it like a brush on canvas; icons for claims (houses),
   campfires, trade/quest facilities; your trail as black dots; other players as grey dots.
3. **Interaction camera.** Tapping a resource or an enemy pans the camera to it and opens its menu locked to it (no drifting).
4. **Walking HUD, bottom right:** jump, scan, combat toggle (likely attack the nearest animal), inventory (shirt), search.
   Bottom left: menu, emote, chat, keyboard. A quest-giver bubble (portrait + distance) points toward the active quest.
5. **Knife combat (extends spec 07).** Hex action slots: basic attack (sword, no cost), stab and slash (red, skills), tackle,
   kick, roll (blue, dodge); an Attack Stance round button that changes how you fight; a red End Combat button. Energy keeps
   recovering in combat.
6. **Harvesting a kill.** The corpse gets a skull marker and the same radial as a resource: Meat 0.6 s, Leg Bone 0.7 s,
   Leather and Teeth blocked (red icon: needs the right tool), Give Up Loot. Skill gain shows bottom left ("Melee +1" bar, "XP 6").
7. **Skill cap.** A skill bar reads FULL when the skill has reached the character level; it waits for a character level-up
   (matches spec 12's global level cap). XP gained is shown.
8. **Cooking a skewer.** Food 1/1 (meat) + Tool 1/1 (Long Stick, Stick, Short Stick - a leg bone qualifies); each ingredient is
   an instance with level and traits (Pointy, Firm); the result preview lists inherited traits (Chunk, Edible, Heated, Meat, Raw,
   Well Cooked); Success Rate 100%; "If crafting fails, materials disappear." (spec 08; PRD :594 Skewer Lv1, stick + fire).
9. **Communication Center:** an NPC hut with a speech bubble, other players around, "Communication Center Missions: Accept
   Gathering Mission"; a cooking-mission tracker (Get meat / Grill skewers at the campfire / Deliver skewers to the camp storage).
