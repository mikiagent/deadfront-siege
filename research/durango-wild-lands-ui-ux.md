# Durango: Wild Lands — UI and UX patterns

**Date:** 2026-10-16
**Source:** UI type names, settings and onboarding configs in the Android client `durango-wild-lands-5-2-1plus2001141741.apk` (build 5.2.1). Read in a scratch folder. No UI art, layouts or game text were copied.
**Companions:** [design lessons](./durango-wild-lands-design-lessons.md), [content inventory](./durango-wild-lands-content-inventory.md), [client systems inventory](./durango-wild-lands-client-systems-inventory.md).

The UI was built in NGUI, an older Unity UI library. The client defines about 1,100 UI types: roughly 280 widgets, 95 screens, pages and popups, and many small list and slot components.

## Seven patterns worth copying

### 1. Tap a thing, get its actions

The core interaction is **contextual action buttons**. Tapping a resource, animal, building or player shows a short group of buttons for what you can do to it right now: gather, attack, enter, repair, inspect. A default button handles the most likely action. A progress gauge shows over the target while an action runs.

There is no verb menu to learn. The world itself is the menu, which suits touch.

### 2. Every screen has a "locator"

Each major screen and element has a locator: inventory, crafting, building, skills, equipment, estate, map, sailing, quests, mission start and delivery, faction requests, and the learning guide. Guides, missions and help text use locators to **open the right screen and point at the right element**.

So a mission that needs rope can take the player straight to the rope recipe, highlighted. This removes most "where is that menu" friction.

### 3. To-dos attached to the things they need

Missions and guides attach **to-do collections** to recipes, blueprints and item slots. When a mission needs an item, its recipe shows a marker, and the needed material slots show what is still missing. The player sees the goal inside the screen where they act on it.

### 4. Predict before committing

Several screens preview an outcome before the player spends anything:

- Crafting shows the **expected tags** the output will carry, based on the chosen materials.
- Pet milestones show predicted tags before the roll.
- Tech support requests show an estimate first.
- Building shows the grid footprint before materials are placed.

This matches the network layer's "Estimate" messages, and the PRD's rule that the game should preview before it consumes.

### 5. Explain the fatigue number

The fatigue gauge appears on the HUD and as a warning on the minimap. A dedicated fatigue panel breaks the current rate into its **reasons**: region level, climate, dirt, hunger and so on, each with its share. Each fatigue category's help text names the remedy, such as washing or drinking for heat. A resistance info popup explains climate resistance.

The game's main limiter is always explained, never a mystery bar.

### 6. Mobile and PC as sibling layouts

Most large widgets come in a base version and a PC version: inventory, crafting, context buttons, equipment slots, chat, experience gauge and tooltips. They share logic and differ in layout. The PC build added keyboard shortcuts with on-screen hints and hover tooltips. Mobile has a joystick group and tap-only flows.

**For Deadfront:** keep one logic layer per screen with a phone layout and a desktop layout, rather than one stretched layout.

### 7. Onboarding as data

Onboarding is driven by **flow files per island role**: tutorial, safehouse, village, personal island, city, unstable island, outpost, instance, editable and offline. Each flow is a sequence of about 375 small events across all files, plus **triggers** that start side sequences when the player arrives somewhere, meets an animal or hits full fatigue.

Event fields include:

- a speaker portrait, name tag and messages
- whether it is a system message, blurs the screen, or runs automatically
- a duration
- a to-do title and to-do list
- a helper target and spotlight to point at UI or world objects
- a short quiz
- a script command, mostly for the guide dog companion and scripted scene events
- a PC override for keyboard players

The guide dog companion is the main onboarding device. Its commands are the most common script verb.

**For Deadfront:** author the tutorial as JSON event sequences with triggers, a helper target and a spotlight, not as code.

## Screen inventory

| Area | What exists |
|---|---|
| HUD | Health, energy and experience gauges, fatigue gauge, quick slots for equipment and emotes, a joystick, battle action buttons, context action buttons, a network status icon, an interactive message line |
| Combat | Target portrait and widget, floating damage numbers, hit effects, a combat state effect layer |
| Inventory | Category tabs, filter popup, container groups for bag and placed storage, equipment slots, slot info popups, action buttons |
| Crafting | Recipe list with filters and sub-lists, recipe info and conditions, material slots with suggested sources, expected-tag preview, step selection for multi-step recipes |
| Building | Build grid and placement locator, add-on selector, interior set and mood info, access rights editor, construction-helper portraits |
| Estate | Estate pages for empty, personal, clan, city and base land, owner and rights widgets |
| Skills | Category list and progress, skill tree view, node info, a learning guide, research tiers for clan and personal labs |
| Map | Map with indicators for players, animals, buildings, factions, flags and rifts, a recommended-island page, favourite islands, shareable map points |
| Pets | Pet list, gauges, cage lists for growing and domestication, pet task selection and progress, milestone roll, celebration and help screens, rank reset |
| Social | Chat tabs and channels, chat rooms, chat bubbles, quick chat, emote selector with favourites, friend lists with requests, follows and blocks |
| Economy | Market with categories, search, history and favourites, shop with tabs, previews, bundles, vouchers and special deals, a wallet popup |
| Story | Faction summaries, radio talk logs, support request lists, a story viewer, "card news" popups |
| Account | Character slots, costume and preset editing, name change, report and block |

## Settings

The settings menu is short:

- **Performance:** resolution in three steps, a battery-save or quality frame rate, shadow and effect quality in two steps.
- **Display:** landscape, portrait or auto-rotate. Landscape is the default.
- **Language:** separate text and voice language.
- **Audio:** separate sliders for effects, ambience, music, and the instrument system.
- **Chat:** who may start a conversation, whether to show chat lines, drawings and bubbles, and auto-translation.
- **Capture filter**, a screenshot-mode toggle.

Settings can be hidden during the prologue or in offline mode. Each entry declares its own control type, so the menu is generated from data.

## Notifications

Push notifications are grouped into player-facing categories. Activity notifications cover craft finished, build finished and skill research finished. Others cover clan, exploring, mail, market, chat, estate and events. Research completion is a **local** notification. Players switch each category on or off.

**Lesson:** long timers only work on mobile if the game tells you when they finish. Durango tied every long wait to a notification type.

## What Deadfront should take from this

1. **Contextual action buttons** on tapped targets, with a default action.
2. A **locator** for every screen, so guides and missions can deep-link and highlight.
3. **To-do markers** on the recipes and slots a mission needs.
4. **Previews** of craft tags, build footprints and other outcomes before spending.
5. A **fatigue breakdown** panel that names each cause and its remedy.
6. **Phone and desktop sibling layouts** over shared screen logic.
7. **Onboarding as JSON event flows** with triggers, spotlights and a companion guide.
8. **Settings and notifications generated from data**, with one notification type per long timer.

## Limits

- Names show what screens existed, not how they looked. No layouts, art or text were extracted.
- This is the end-of-service build. Some live-era screens may have been removed or hidden.
