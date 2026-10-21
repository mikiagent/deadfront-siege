# CHAT: Durango region chat (claude/mmo-chat)

Builder report. Owner: "region chat". Spec `docs/design/durango-prompts/20_region_chat.md`, reference
`docs/reference/durango-region-chat.webp`. Branch `claude/mmo-chat`, stacked on `claude/mmo-net`
(`18d0d594`). Integrator: apply `claude-mmo-net-hooks.patch` (NET) and then
`claude-mmo-chat-hooks.patch` (this package). No Meshy or other credits spent.

## What shipped

| File | What it is |
|---|---|
| `game/scripts/ui/chat_log.gd` (`ChatLog`) | The lines this client keeps, per channel (`region`, `system`), newest last, 100 per channel. Region lines come from NET's `evt chat` on the given `NetClient`; every field is checked and cleaned again on the client (`NetChat.clean`, length caps, integer id, numeric ts clamped to now), so a broken or hostile server cannot inject control or bidi characters. `send()` is `chat.send {text}`; the line itself arrives as the server's echo. `system()` adds a System line (a repeat within 5 s refreshes the last one). `groups()` stacks one sender's consecutive lines; `ago()` is the grey "1h 28m ago". |
| `game/scripts/ui/chat_screen.gd` (`ChatScreen`) | The screen. Left: Region and System, dotted separators, the selected one gold in yellow corner brackets. Right: header with the title, the gold eye (overlay on/off, crossed and grey when off) and a plain X; rows with gold names, text or a white sticker, a small grey relative time, one sender's lines stacked under one name, alternating light and dark tints over the blurred world, newest at the bottom with a short eased scroll; input bar "Enter message", "+" (sticker picker), "Send". Region offline: a banner that says so and why, field/+/Send disabled. System is read-only and works offline. The input bar rides above the on-screen keyboard (`DisplayServer.virtual_keyboard_get_height`). Typed W/A/S/D do not walk the survivor (movement actions are released while the field has focus) and Esc closes the picker, then the screen; these two are in code only, t_chat does not cover them. |
| `game/scripts/ui/chat_hud.gd` (`ChatHud`) | The HUD side: the CHAT hex (menu row, after SKILLS), the `ChatLog`, the screen (CanvasLayer 96, with the other modals) and the overlay: the newest 4 Region lines for 30 s over the bottom-left hex stack while the eye is on and the screen is closed. The overlay never takes a tap and keeps off the HUD's blocks and hexes (`HudLayout.taken_rects`); at 844x390 HANDS cuts it short instead of it covering HANDS. Island arrivals (`World.island_changed`) become System lines here. |
| `game/scripts/ui/chat_emotes.gd` (`ChatEmotes`) | Eight white stickers drawn in code (smile, laugh, wink, wow, sad, angry, skull, heart). A sticker travels as an ordinary chat line whose whole text is its code (`:skull:`), so NET's text rules cover it and needs no protocol change. |
| `game/scripts/ui/chat_blur.gdshader` | The backdrop: the world blurred and slightly dimmed (5x5 taps of the screen texture). |
| `game/scripts/dev/chat_lab.gd`, `game/scenes/dev/chat_lab.tscn` | Windowed lab: home island, the real HUD, a local `NetServer` and three real clients (the game's own `Game.net` plus Mira and Rook) in one island room, exchanging 12 real lines over localhost sockets; System lines from the game's own paths (island load, a level-up, a HUD notice). Modes `region`, `system`, `picker`, `overlay`, `offline`. |
| `game/tests/t_chat.gd` + `chat_checks.gd` | 59 checks; see Tests. |
| `docs/orchestration/reports/claude-mmo-chat-hooks.patch` | `hunt_hud.gd` (W1-UI's file): `var chat: ChatHud`, `ChatHud.attach(self)` in `_build_menu_row`, `chat.hex` in the menu row in `_layout`, `notice()` and `_on_level_up()` feed System. Applies cleanly on this branch and on `claude/mmo-overhaul` (checked with `git apply --check` against overhaul's `hunt_hud.gd`). `hud_layout.gd` needs no change: it does not move the menu row. |

## Decisions

| Decision | Why |
|---|---|
| No "+ New Group" | NET has no group ops (`grep group game/scripts/net/*.gd`: only a comment in `presence_sender.gd`). The prompt says to leave it out; the left column ends after System. |
| System = HUD notices + level-ups + island arrivals | That is what the HUD announces today. Notices cover warnings, "Bag is full", pet level-ups ("X reached Lv. N!"), bonding, craft blocks, save problems. The HUD has no rare-find announcement to forward (no rarity notice anywhere in `scripts/`), so there is none. |
| Stickers as `:code:` text | The docs list no sticker set (`# ASSUMPTION`). Text codes need no server change, pass NET's validation and rate limit, and an older client shows the code as text. |
| Durango colours copied from `InvTheme` | INVUI (`claude/mmo-invui`) is not on this base, so the bag family's gold `#F2C84C`, bracket `#E6BE54`, text `#ECEBE4`, grey `#A6A69B`, frame ink and button edge are copied as constants (`shortcut:` in `chat_screen.gd`; switch to `InvTheme` once INVUI is merged). |
| Player text never markup | Names, lines and banners go into `RichTextLabel`s with `bbcode_enabled = false` and `add_text()` only, and translation lookups off. The server's "Not sent: <reason>" is rendered the same way. |
| Region lines are not kept past 100 per channel, nothing persists | The server keeps no history (`# ASSUMPTION`). |
| The overlay shows Region only | System lines are already on the HUD as notices and banners; repeating them over the game would double them (`# ASSUMPTION`). |

## Tests

`t_chat.gd` (standalone, like `net_tests.gd`; prints `[t_chat] PASS` or one FAIL line per check):

- Pure: "1h 28m ago", "just now", "5m ago", "2d ago", a future ts never negative; grouping stacks one sender's consecutive lines, a break starts a new block, System lines never stack.
- Offline (a real `NetClient`, no server): Region shows the offline banner; field, + and Send are disabled; a System notice shows once with its time; the selected channel is gold.
- Two real clients (Alice, Bob) through a real `NetServer` on a free localhost port: a line before joining is refused with the reason; both join one island; Alice's line reaches Bob (name and account id) and comes back to Alice; Bob's `:skull:` reaches Alice; Bob's screen shows three blocks (Alice, Bob, Alice x2), names gold, the name and its first line on one baseline, alternating tints.
- Hostile text: `[b]bold[/b] [url=...]tap[/url] [img]res://icon.svg[/img] %s {0} [color=red]x` arrives and draws literally; every line is a `RichTextLabel` with BBCode off; malformed `evt chat` (string id, non-string text, float or negative id, over-long text, blank after cleaning) is dropped; control and bidi characters from a server are stripped; a ts from the future is clamped.
- Layout at 844x390 and 1600x900: every button and the field are 44 px or more both ways; nothing leaves the view; the picker opens on "+", a picked sticker reaches Alice and the picker closes; with a 200 px keyboard the input bar sits above it and drops back after.
- HUD (needs the hooks patch; without it the run prints a note and skips these): the CHAT hex sits in the menu row after SKILLS; a HUD notice and a level-up become System lines; the hex opens the screen. The overlay: an island arrival is a System line; a fresh Region line shows it, newest last, inside the view and above the hex row; it never takes a tap; it hides while the screen is open; the eye turns it off and back on; the X closes the screen; no fresh lines, no overlay.
- After Bob disconnects, Region keeps its lines and says it is offline.

Old behaviour fails: on the base there is no `ChatLog`/`ChatScreen`, so `chat_checks.gd` cannot compile, and the runner counts a script that does not compile as a FAIL (not run on the base; this is the runner's code path). Mutation check (one run, files restored from a backup and compared with `cmp`): BBCode on with `append_text`, no grouping, "just now" replaced by seconds, and the offline text changed printed `[t_chat] FAIL count=11`, each mutation failing its own checks.

## Gates

All through `gslot.sh`, seen this session after the last code change (branch commit `7665de8`; the
report and the lab's `.uid` are the only later changes).

Integrated state: `claude-mmo-net-hooks.patch` and `claude-mmo-chat-hooks.patch` applied to the work
tree (reverted afterwards), import first (alarm 900):

```
import exit=0 errors=0
t_chat exit=0 errors=0 :: [t_chat] PASS
t_ui exit=0 errors=0 :: [t_ui] PASS
t_player exit=0 errors=0 :: [t_player] PASS
t_save exit=0 errors=5 :: [t_save] PASS          (the 5 deliberate SCRIPT ERRORs)
t_data exit=0 errors=0 :: [t_data] PASS items=223 recipes=155
t_items, t_build, t_ai, t_combat, t_canim, t_iconart, t_light, t_occlude, t_server_domain,
t_srvdom, t_structart, t_tame, t_w2_skills, t_web: exit=0 errors=0 PASS
t_harbour exit=0 errors=0 :: [t_harbour] PASS islands=15
t_lighting exit=0 errors=0 :: [t_light] PASS     (that file prints the t_light tag on base too)
t_uiicons exit=0 errors=0 :: [t_uiicons] PASS ids=171 files=114 ...
run_all exit=0 errors=0 :: [tests] PASS
net_tests exit=0 errors=0 :: [net_tests] PASS
smoke exit=0 :: SMOKE PASS                       (tools/smoke.sh --no-import)
```

Branch alone (no hooks): `t_chat exit=0 errors=0 :: [t_chat] PASS` with the line
`[t_chat] note: hunt_hud.gd has no chat hook (claude-mmo-chat-hooks.patch not applied); HUD feed checks skipped`,
and `smoke exit=0 :: SMOKE PASS`.

Lab: 11 windowed `chat_lab` runs (below), each `rc=0`, 0 SCRIPT ERROR, each printing
`[chat_lab] ready mode=<mode> online=true region=12 system=3` (offline: `online=false region=0 system=3`).
The only WARNING in the lab logs is the navigation bake warning from `LabKit.build`, which every lab that
uses LabKit prints.

## Shots

Windowed, with both hooks patches applied, from `chat_lab` (12 real lines from three real clients
over localhost; System lines from the island load, a level-up and a HUD notice). In
`/private/tmp/claude-501/-Users-milankinzy-Documents-deadfront-siege/72cebc8b-d241-430b-9ea6-94d65339bfef/scratchpad/chat/shots/`:

| Shot | What it shows |
|---|---|
| `f_region_1600x900_fwd.png`, `f_region_1600x900_gl.png` | Region at the desktop judge size, Forward+ and gl_compatibility |
| `f_region_844x390_fwd.png`, `f_region_844x390_gl.png` | Region on the landscape phone, scrolled to the newest line |
| `f_system_1600x900_gl.png`, `f_system_844x390_fwd.png` | System: "Arrived at Private Grassland.", "Level up: Lv. 2.", "Bag is full."; read-only bar |
| `f_picker_844x390_gl.png` | The sticker picker over the rows |
| `f_overlay_1600x900_gl.png`, `f_overlay_844x390_fwd.png` | The HUD: CHAT hex after SKILLS and the overlay with the two lines under 30 s old, cut short by HANDS on the phone |
| `f_offline_1600x900_gl.png`, `f_offline_844x390_gl.png` | Region with no server: the offline banner, "Offline" field, disabled + and Send |

Against the reference: same two-panel layout (channel column about 16 % wide), bracketed gold
"Region", dotted separators, dark header with the title, gold eye, divider and X, gold names with
text or white stickers and small grey times, Survivor's two lines stacked under one name, alternating
row tints over the blurred world, "Enter message" / "+" / "Send" bar. Differences: no "+ New Group"
(see Decisions); our font is the narrowed default, not Durango's condensed face; the gl_compatibility
blur is softer-edged but weaker than Forward+'s.

## Limits and notes for the next agent

- The blur is 25 taps per pixel every frame (`shortcut:` in the shader). In gl_compatibility it is softer than in Forward+ (the screen texture's mip levels do the extra smoothing in Forward+), but the world still reads as blurred in both.
- Faint HUD hexes show through the blur at the bottom left; the HUD stays drawn under the screen like it does under the bag.
- Seen in code, not reproduced and not CHAT's file: `player_input.gd` arms `_desktop_click_fallback` in `_input` for every left click and only clears it on an unhandled tap, so a desktop click on any modal control (chat Send, the bag) that sits over a craft station's projected position (within 96 px) can still start that station's interaction. Owner of `player_input.gd` should clear the flag when the GUI consumed the click.
- Region chat on the web build needs `?online=ws://...` (NET); without it Region shows the offline banner, which is the honest state.
- The chat log lives in the HUD (built once in `main.gd`), so it survives island travel; a reconnect to a new island room keeps the old room's lines.
