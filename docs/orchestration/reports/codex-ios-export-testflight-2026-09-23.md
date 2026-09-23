# Codex iOS export and TestFlight diagnosis, 2026-09-23

## What shipped

- Ran the existing Godot debug export, built its generated Xcode project for an iPhone 17 Pro simulator, installed `com.deadfront.app`, and launched it. The downloader shell rendered. Forcing the full home lab or smoke path stayed on Godot's splash screen for more than a minute; a process sample showed the simulator spending its time in software OpenGL. No physical iPhone was connected.
- Fixed the release script to request Godot `--export-release` for TestFlight. The former script requested `--export-debug` even though Xcode archived its Release configuration. A mode marker now prevents `--no-export` from reusing a debug project.
- Aligned `tools/release.env` with the current `com.deadfront.app` preset and App Store Connect app. The old value pointed the read-only TestFlight status tool at the separate DurangoLike app.
- Made Xcode, IPA export, validation and upload failures stop the scripts. The former export, validation and upload commands used `|| true` and could print an upload success line after an error. The simulator helper now uses the built app's bundle ID rather than the old hardcoded ID.
- Expanded the read-only App Store Connect status tool to print build beta state, group access and tester states without tester emails. Updated `docs/release/testflight.md`.

## Evidence

- `tools/sim_run.sh`: Godot debug export, Xcode Debug build succeeded, `com.deadfront.app` launched, shell screenshot at `~/Library/Caches/durango-sim/sim_shot.png`.
- `tools/release_ios.sh --no-export --validate` rejected the debug project as intended.
- `tools/release_ios.sh --validate` performed a Godot release export, then Xcode stopped with: no installed profile matching `Deadfront CI App Store`.
- Direct unsigned Xcode Release archive succeeded at `/tmp/deadfront-release-unsigned.xcarchive`. Its app bundle ID is `com.deadfront.app`.
- App Store Connect read-only query: Deadfront build `202609220014` is `VALID`, `IN_BETA_TESTING`, unexpired, assigned to internal group `Test` with all-build access and one `ACCEPTED` tester. That tester has no recorded app devices. The older DurangoLike app is separate.
- `bash -n` for edited shell scripts, `python3 -m py_compile tools/asc_status.py`, `git diff --check` and `tools/smoke.sh` all passed.

## What failed or remains unknown

- Signed release validation is blocked by local signing state. The active Deadfront App Store profile in Apple's account contains distribution certificate SHA-1 `AEA060BAE33BB5E6D4C37431D3366AE06F82BDF7`. This Mac has a private key for a different valid distribution certificate, SHA-1 `464981AB8499BEB766F8CB5C0D10D418FF6038FB`. No matching Deadfront profile is installed. A matching profile using the installed certificate, or the other certificate's private key, is needed.
- No build was uploaded in this task. The new release export has not passed signed IPA validation.
- The exact TestFlight message on the owner's phone is not known. The current build and group are active in App Store Connect, so a server-side processing or group-assignment block was not found. The phone was not connected to this Mac.
- Xcode warned about empty camera, microphone and photo-library usage descriptions. Those warnings did not stop the simulator build or unsigned archive and did not explain the current TestFlight install symptom.

## Credits spent

- Meshy: 0.

## What the next agent needs

1. With account authorization, create or obtain a Deadfront App Store profile that matches an installed distribution private key; then rerun `tools/release_ios.sh --validate` and inspect the signed IPA.
2. Obtain the exact TestFlight phone error and the Apple Account used in the TestFlight app, then test install on a connected iPhone. The active tester record alone does not prove the phone uses that account.
3. Upload a newly validated release build only after approval. Check App Store Connect processing and tester install status afterward.
