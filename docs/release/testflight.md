# Shipping a build to TestFlight

First upload: 2026-09-17, build 0.1.0 (1), delivery `3305d9a9-1f45-499d-948e-6a1947705807`.

## One command

```
tools/release_ios.sh
```

It exports the Xcode project from Godot, archives with automatic signing, exports a signed App Store IPA, validates it, and uploads it. Build number is the timestamp, so every run is a higher build. Bump `MARKETING_VERSION` in `tools/release.env` when the version should change. `--validate` does everything but upload; `--no-export` reuses the last Godot export.

## What it relies on (all already in place on this Mac)

| Thing | Where | Notes |
|---|---|---|
| Godot 4.7.1 mono export templates | `~/Library/Application Support/Godot/export_templates/4.7.1.stable.mono/` | installed 2026-09-17 |
| iOS export preset | `game/export_presets.cfg` | team `U6SV8Z7K4S`, bundle `com.durangolike.dev`, `export_project_only`, push notifications off |
| Xcode 27 with the licence accepted and an Apple ID signed in | Xcode, Settings, Accounts | needed for automatic provisioning |
| App Store Connect app record | App Store Connect, My Apps | bundle `com.durangolike.dev` |
| App Store Connect API key | `~/.appstoreconnect/private_keys/AuthKey_678H6PU9Y9.p8` | role App Manager; Key ID and Issuer ID in `tools/release.env` |

## Gotchas learned the hard way

- Godot writes an `aps-environment` entitlement even with push notifications off; free and automatic provisioning rejects it. `tools/export_ios.sh` strips it after every export.
- The generated project hard-codes `Apple Distribution` for Release, which conflicts with automatic signing. Archiving with `CODE_SIGN_IDENTITY="Apple Development"` and letting `-exportArchive` re-sign for the store is the fix.
- `xcodebuild -exportArchive` with `destination: upload` fails with "team IDs for account (null)" on this Mac. Uploading with `xcrun altool --apiKey/--apiIssuer` works. Validation passing also proves the app record exists.
- The simulator is not viable: Godot ships only an Intel simulator slice and Xcode 27's simulators are Apple Silicon only.
- `ITSAppUsesNonExemptEncryption=false` in Info.plist avoids the export-compliance question on every build.

## After the upload

Processing takes about ten minutes. Then in App Store Connect, TestFlight tab: add yourself to an internal testing group once (Internal Testing, +, add tester by Apple ID). Install the **TestFlight** app on the phone, accept the invite, install the build. Each later upload appears automatically for that group.

## Android (later)

Needs an Android SDK, JDK 17, a keystore, and the Godot Android preset. Not set up.
