# Deadfront: Natural Resource Color and Material Appearance System

> Owner spec, 2026-10-28 (Milan, project chat). Binding design input. Roadmap features: `material-appearance`,
> `crafted-tint`, `building-material-look`, `material-inspect` (Phase 1 / 3). The wood palettes below are illustrative,
> not sampled game colors.

Design and implement a **Durango: Wild Lands-inspired material color system** where the natural appearance of gathered resources influences the visual appearance of crafted items, furniture, buildings, and structures.

## Core Concept

Resources should have two independent sets of properties:

1. **Visual properties:** Natural color, texture, grain, and material appearance.
2. **Mechanical properties:** Level, quality, durability, positive traits, negative traits, and rare special traits.

A resource's physical color must not be confused with its rarity or trait quality.

## 1. Natural Wood Color Variation

Different tree species produce logs with distinctive natural colors.

Example wood types:

| Wood Species | Natural Appearance |
|---|---|
| Mahogany | Warm reddish-orange / reddish-brown |
| Almond | Very dark brown, nearly black |
| Oak | Pale cream / whitish wood |
| Palm | Light tan / pale yellow |
| Maple | Warm golden brown |
| Pine | Light yellow-brown |
| Walnut | Rich chocolate brown |
| Ebony | Deep black-brown |

These are illustrative color palettes inspired by Durango's material variety, not exact sampled game colors.

Each species should have a consistent color identity, with subtle natural variation between individual logs.

## 2. Material Appearance Inheritance

The appearance of raw materials should carry through into the crafted objects that use them.

Examples:

- Mahogany logs produce reddish wooden walls, floors, furniture, and structural beams.
- Almond logs produce very dark wooden buildings.
- Oak logs produce pale or nearly white wooden structures.
- Palm logs produce light tan buildings.

Players should be able to deliberately harvest particular trees to achieve their desired architectural appearance.

This gives gathering a cosmetic purpose beyond collecting crafting ingredients.

## 3. Separate Material Traits From Appearance

Wood color must remain independent of the resource's mechanical attributes.

For example, two mahogany logs can have identical reddish-brown appearances but different traits:

- Mahogany Log A: Firm Lv. 4
- Mahogany Log B: Lightweight Lv. 6
- Mahogany Log C: High Density Lv. 4
- Mahogany Log D: Rare special trait

Trait indicators should use the established Durango-inspired classification:

- Gray: Negative traits
- Yellow: Positive traits
- Green: Rare special traits

A green trait does not mean the log itself is green. Likewise, darker wood must not automatically be stronger or rarer.

## 4. Crafting and Construction

When crafting an object, use the selected material's visual properties to determine its appearance.

Requirements:

- Crafting previews should display the resulting color before construction.
- Different wood species should produce visually distinct versions of the same recipe.
- Material selection should matter aesthetically and mechanically.
- Mixed-material recipes should have predictable visual inheritance rules.
- Players should be able to select materials for appearance without sacrificing access to detailed trait information.

For recipes using multiple wood species, define which ingredient controls each visible component rather than averaging every material into one indistinguishable color.

## 5. Integration With Deadfront's Building System

Integrate natural material coloration into Deadfront's prefab-first construction system.

Requirements:

- Walls, roofs, floors, doors, furniture, fences, and structural supports inherit appropriate material appearances.
- Buildings can contain multiple wood colors.
- Players can preview material colors when selecting construction ingredients.
- Completed prefab structures retain their material appearances when packaged, transported, traded, and redeployed.
- Temporary expedition bases and permanent settlements use the same material appearance rules.

Skilled builders should be able to specialize in creating beautiful structures using rare or aesthetically desirable materials.

## 6. Resource Inspection UI

When inspecting a resource in inventory, show:

- Resource name and species
- Material level
- Natural color / color family
- Material texture or grain
- Durability and processing information
- Positive, negative, and special trait boxes
- Crafting uses

Add a small material swatch or preview so players can recognize the wood's natural appearance.

The gathering interface should preserve that appearance information when resources are collected.

## 7. Design Philosophy

The goal is to make the **physical identity of resources meaningful**.

Players should have reasons to seek particular resources for three distinct purposes:

1. **Functionality:** Materials with desirable combat, construction, or crafting attributes.
2. **Appearance:** Materials with desirable colors, grain patterns, and textures.
3. **Trade value:** Materials that are difficult to obtain, aesthetically desirable, or possess valuable traits.

A basic log should still be useful, but a perfectly colored log with excellent crafting traits could become a sought-after commodity.

**Important:** Do not implement this as a conventional rarity-based color system. Natural resource color, material level, and material traits must remain separate data dimensions.

The overarching design goal is to make resource gathering, crafting, building customization, and player-driven trading deeply interconnected, as they were in Durango: Wild Lands.
