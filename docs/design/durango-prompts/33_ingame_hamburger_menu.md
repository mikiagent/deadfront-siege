# 33. In-game hamburger menu — main navigation overlay (owner reference, 2026-10-27)

Owner's words, verbatim: "in game, when you press menu you get this." Two screenshots pasted in chat (not saved to `docs/reference`), followed by the owner's own reference write-up, kept verbatim below.

> **Objective:** Document and reconstruct the historical in-game main navigation menu from Durango: Wild Lands, activated using the bottom-left hamburger button.
>
> This is NOT the game's title screen, login screen, pause menu, character screen, or inventory. It is the expanded navigation overlay displayed on top of active gameplay.
>
> ## Reference composition
>
> - Landscape-oriented mobile game interface.
> - Isometric 3D prehistoric survival environment remains visible.
> - A player character stands in the world behind the interface.
> - Two vertical groups of navigation options are positioned along opposite sides of the screen.
> - Dark, slightly transparent overlay surfaces maintain readability without completely hiding gameplay.
> - Minimal ornamentation, white icons, clear labels, and compact spacing.
>
> ## Left navigation
>
> 1. Character
> 2. Skill
> 3. Craft / Build
> 4. Bag
> 5. Animals
> 6. Island Market
>
> ## Right navigation
>
> 1. Domain
> 2. Shop
> 3. Tasks
> 4. Clan
> 5. Friend
> 6. Encyclopedia
>
> ## Upper utilities
>
> - Menu lock / display mode
> - Mail and notification indicators
> - Settings
> - News / announcements
> - Social shortcut
> - T-Stone balance
> - Premium currency balances
>
> ## Interaction behavior
>
> - Tap the hamburger button to reveal navigation.
> - Selecting an option opens that system's interface.
> - The game world remains visible beneath the navigation overlay.
> - Display mode can be changed using the lock control.
> - Notification badges identify items requiring attention.
> - Closing the menu returns the player to normal exploration.
>
> ## Visual details to analyze
>
> Pay particular attention to icon dimensions, vertical spacing, margins, text alignment, background transparency, visual hierarchy, screen-edge padding, currency display, and the relationship between gameplay and navigation.
>
> ## Research fidelity rules
>
> Preserve historically documented layout and naming when describing Durango. Distinguish variations across screenshots and releases. Do not invent undocumented Durango menu features.
>
> Do not generate a new artistic interpretation yet. This specification is for future reference and will be used to develop an original Deadfront menu later.

## Orchestrator's reading and reconciliation (not the owner's text)

### Variations between the two shots
- The fuller shot matches the spec exactly: left column **Character, Skill, Craft / Build, Bag, Animals, Island Market** (icons at the entry's left), right column **Domain, Shop, Tasks, Clan, Friend, Encyclopedia** (icons at the column's right, right-aligned labels).
- The earlier shot (starter jungle island) drops **Island Market, Domain, Shop, Clan** and shows **Tasks** parked at the bottom of the left column beside a red-star badge; the right column shortens to Friend + Encyclopedia. Read as progressive unlock/entitlement, with Tasks migrating to the right column once the full set is available. Treat the exact gating as unverified — record it when a Deadfront build gates its menu.
- The fuller shot also shows wide promo banners docked bottom-centre ("Various Houses", "Childhood Memory Package") — shop promotions inside the overlay, not new navigation entries.
- Both shots keep a camera (screenshot) button at the bottom-right under the overlay.

### What the on-image annotations mark
- Red arrow on **Skill** (first shot): the skill trees of `03`, `12`, `skills.md` open from here.
- Red circle on the **padlock** (header, far left of the utility band, both shots): the menu lock / display-mode control the spec lists.
- Red ellipse around the **currency readouts** (header right): see below.

### Header band (utilities + currencies)
- Left: padlock, mail with a red count badge (1), settings gear, news megaphone, social-network glyph; thin separators between them.
- Right: **three** currency counters, not two — a silver coin **16,372** (215 in the starter shot), a gold gem **570** (20) with a "+" purchase chip, and a gold hexagon **0** with a "+". The coin is the soft/market currency (the spec calls it the T-Stone balance; `06` uses T-Stones), the gem is the premium currency, and the third currency is real but unnamed in our docs — keep an explicit third-currency slot in the ECON spec until the owner names it.
- Note the asymmetry with other screens: skill/tree screens (`skills.md`) show **two** wallets plus an **SP counter** (79 / 133), and 13/14 header furniture shows two — the SP counter replaces the hexagon badge out of the menu.

### Entry → our spec mapping (reconciliation)
| Entry | Covered by |
|---|---|
| Character | 13 (Character → Gear screen) |
| Skill | `03`, `12`, `skills.md` reference UI |
| Craft / Build | 30 (Craft/Build UI), 04 (recipe browser), 10 (construction quality) |
| Bag | 13 |
| Animals | 23 (pet radial), 02, 09 |
| Island Market | 14 (Buy/My Market/Sell), 06 |
| Domain | 29 (land claim), 18 (domain banner) |
| Shop | **unspec'd** — cash/promo store; the screenshots' promo banners and "+" chips live here |
| Tasks | **unspec'd** — quest/task center; 25 shows the mission tracker and quest bubble pattern |
| Clan | **unspec'd as UI**; game-vision tribes are the design landing zone |
| Friend | **unspec'd**; 20 (region chat) is adjacent social space |
| Encyclopedia | **unspec'd** |

### Ground rules carried into later work
- The world stays live under a translucent overlay; closing returns to play. This never suspends the simulation (compare 25's interaction camera: tapping objects keeps the menu locked to them).
- Notification badges: a mail count and a dot/badge on Tasks — badge mechanics belong with the Tasks spec when one exists.
- Per the owner's fidelity rule: this file documents the historical overlay for reference only. When the original Deadfront menu is designed, start a new design doc — do not edit the prompts folder into a look-alike.
