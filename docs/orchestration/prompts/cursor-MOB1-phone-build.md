# Cursor milestone MOB1 — a build that runs on a phone

The owner wants to play this on a phone. Target iOS first (Xcode 27 is installed on this Mac; no Android SDK is). Do this after M5 so the performance work is measured against a real island, but the export scaffolding can start any time.

## Tasks

1. **Export preset.** Add `game/export_presets.cfg` with an iOS preset: bundle id `com.durangolike.dev` (`# ASSUMPTION:`, owner can rename), landscape only, minimum iOS 16, `mobile` renderer, ETC2/ASTC textures, portrait disabled, status bar hidden, the app icon generated from `icon.svg`. Export templates for 4.7.1 mono are installed by the orchestrator under `~/Library/Application Support/Godot/export_templates/4.7.1.stable.mono/`; if they are missing, say so in the report instead of downloading a gigabyte.

2. **Xcode project.** `godot --headless --export-debug iOS game/export/ios/durango.xcodeproj` style export (Godot produces an Xcode project for iOS). Document the exact command in `tools/export_ios.sh`. Do not attempt signing from the command line; the owner opens the project in Xcode, selects their personal team, and runs on the device. Write those clicks into the report.

3. **Performance budget on device**, measured with the Godot monitor overlay (add an FPS/draw-call/memory readout toggled by the existing `debug_toggle` action): 60 fps on the M5 island on an iPhone from the last three years, under 250 draw calls in the camp view, under 400 MB memory. Levers, in this order: `MultiMeshInstance3D` for all vegetation, visibility ranges on props, shadow size 1024 on mobile, creature count cap from `game.gd`, texture size cap 1024 for creature albedo on the mobile export (import setting overrides), disable SSAO/SSR/glow in the mobile environment.

4. **Touch pass on a real screen.** Everything in `addendum-mobile.md` re-checked on the device: joystick zone, button sizes with a thumb, safe area on a notched phone, inventory and craft panels one-handed, pinch zoom limits, map screen. Fix what fails.

5. **Session model.** Background/foreground handling: pause the game and autosave on `NOTIFICATION_APPLICATION_PAUSED`, resume cleanly; the offline-rest rule from M6 applies to time spent backgrounded.

## Acceptance
- `tools/export_ios.sh` produces an Xcode project without errors on this Mac.
- The report includes the on-device measurements and a photo or screenshot of the game running on the phone.
- Commit as `MOB1: iOS export and mobile performance pass`.
