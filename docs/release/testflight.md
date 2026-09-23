# Shipping a build to TestFlight

The current TestFlight app is **Deadfront** (`com.deadfront.app`). The older **DurangoLike**
(`com.durangolike.dev`) is a separate App Store Connect app. Check the bundle ID when looking
for builds or tester invitations.

## One command

```
tools/release_ios.sh
tools/release_ios.sh --validate  # export, sign and validate without uploading
```

It exports a **release** Xcode project from Godot, archives with manual App Store signing,
exports a signed IPA, validates it, and uploads it. Build number is the timestamp, so every
run is higher. Bump `MARKETING_VERSION` in `tools/release.env` when the version should change.
`--validate` does everything except upload. `--no-export` reuses only a project produced by
`tools/export_ios.sh --release`; it refuses a debug export. `tools/export_ios.sh` alone defaults
to debug for local simulator and development-device runs.

## What it relies on

| Thing | Where | Notes |
|---|---|---|
| Godot 4.7.1 mono export templates | `~/Library/Application Support/Godot/export_templates/4.7.1.stable.mono/` | installed 2026-09-17 |
| iOS export preset | `game/export_presets.cfg` | team `U6SV8Z7K4S`, bundle `com.deadfront.app`, `export_project_only`, push notifications off |
| Xcode 27 with the licence accepted | `/Applications/Xcode.app` | archives and exports the IPA |
| App Store distribution certificate and matching profile | Login keychain and `~/Library/MobileDevice/Provisioning Profiles/` | `Deadfront Local App Store`; certificate SHA-1 and profile name are recorded in `tools/release.env` |
| App Store Connect app record | App Store Connect, My Apps | Deadfront, bundle `com.deadfront.app` |
| App Store Connect API key | `~/.appstoreconnect/private_keys/AuthKey_678H6PU9Y9.p8` | role App Manager; Key ID and Issuer ID in `tools/release.env` |

## Gotchas learned the hard way

- Godot writes an `aps-environment` entitlement even with push notifications off; free and automatic provisioning rejects it. `tools/export_ios.sh` strips it after every export.
- The Release archive requires an installed provisioning profile for `com.deadfront.app` whose
  distribution certificate has a private key on this Mac. The existing `Deadfront CI App Store`
  profile uses a different certificate. On 2026-09-23, `Deadfront Local App Store` was created
  using this Mac's distribution certificate; it signed, exported and validated build
  `0.2.0 (202609231330)` successfully.
- The script now stops on archive, IPA export, validation or upload errors. Older versions
  suppressed some failures and could print an upload success message without a successful upload.
- `xcodebuild -exportArchive` with `destination: upload` fails with "team IDs for account (null)" on this Mac. Uploading with `xcrun altool --apiKey/--apiIssuer` works. Validation passing also proves the app record exists.
- `tools/sim_run.sh` adds the locally built arm64 simulator slice and launches the debug
  shell. Simulator rendering is too slow for a reliable full-game performance test.
- `ITSAppUsesNonExemptEncryption=false` in Info.plist avoids the export-compliance question on every build.

Check processing, tester-group access and accepted tester count:
`uv run --with pyjwt --with cryptography python3 tools/asc_status.py`.
To invite a tester and attach a build, use
`uv run --with pyjwt --with cryptography python3 tools/asc_testflight.py <email>`.
That second command changes App Store Connect.

## After the upload

Processing takes about ten minutes. Then in App Store Connect, TestFlight tab, confirm the new
build is available to the existing internal group `Test`. The invited tester is already in that
group. On the phone, open the **Deadfront** listing in TestFlight and install the new build.
The older **DurangoLike** listing will keep showing its older build.

## Android (later)

Needs an Android SDK, JDK 17, a keystore, and the Godot Android preset. Not set up.
