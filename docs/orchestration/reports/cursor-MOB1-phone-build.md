# Cursor MOB1 — iOS export and mobile performance pass

A phone build of the Durango-like. iOS first; this Mac has Xcode 27 and Godot 4.7.1 mono templates, no Android SDK.

## What shipped
- `game/export_presets.cfg`: iOS, bundle `com.durangolike.dev` (`# ASSUMPTION:` owner can rename), landscape only (project orientation 4), min iOS 16, iPhone family, status bar hidden via Info.plist, icon from `icon.svg`, `export_project_only` so Godot writes an Xcode project instead of an IPA. Team ID `U6SV8Z7K4S` is required for Godot to export; the owner still picks the team in Xcode and signs there.
- `tools/export_ios.sh` — unsigned debug export. Ran cleanly and produced `game/export/ios/durango.xcodeproj` (gitignored).
- Performance: F3 / `debug_toggle` HUD shows fps, draw calls, static memory. Mobile directional shadow 1024, MSAA off on mobile, SSAO/SSR/glow already off in `IslandRuntime`, MultiMesh grass, harvest visibility range 70 m, creature cap 24, importer default texture size 1024.
- Session: `NOTIFICATION_APPLICATION_PAUSED` pauses the tree and autosaves; resume applies tent rest for the wall-clock gap (same rule as M6 offline rest).

## Export
```
tools/export_ios.sh
```
Godot 4.7.1.stable.mono templates were present at `~/Library/Application Support/Godot/export_templates/4.7.1.stable.mono/` (`ios.zip` included). No template download.

### Xcode clicks (owner)
1. Open `game/export/ios/durango.xcodeproj`.
2. Select the **durango** target → Signing & Capabilities.
3. Check **Automatically manage signing**.
4. Team: your **Personal Team** (Godot filled `U6SV8Z7K4S` from this Mac; change it if needed).
5. Bundle ID stays `com.durangolike.dev` unless Apple rejects the name.
6. Destination: your iPhone. Plug in, trust the computer, enable Developer Mode if iOS asks.
7. Run (▶). First launch may need Settings → General → VPN & Device Management to trust the developer app.

Do not codesign from the Godot CLI.

## On-device measurements
Not taken from this agent — no phone was in the loop. The HUD is on `debug_toggle` so a device run can read fps / draws / MB against the budget (60 fps on the island, &lt;250 draws in camp, &lt;400 MB). Headless Mac export does not represent device GPU.

No device screenshot is attached for the same reason.

## Touch pass
Re-checked against `addendum-mobile.md` in code: joystick + 64 px buttons including MAP, craft/inventory tap targets 64 px, safe-area padding on those panels, `tap` ignores Controls and the touch layer. Real notched-phone thumb reach still needs a device pass.

## Smoke
`tools/smoke.sh` → `SMOKE PASS`.

## Next
Owner: install on an iPhone from the last three years, F3 the HUD in camp, and send fps / draws / memory if anything misses budget.
