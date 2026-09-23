# Codex Deadfront TestFlight upload, 2026-09-23

## What shipped

- Created an iOS App Store provisioning profile named `Deadfront Local App Store` for `com.deadfront.app`, using the distribution certificate whose private key is installed on this Mac. Installed it locally; its application identifier is `U6SV8Z7K4S.com.deadfront.app` and `get-task-allow` is false.
- Updated `tools/release_ios.sh` and `tools/release.env` to use that profile and certificate for both the Xcode archive and IPA export.
- Exported the Godot project in release mode, built and signed the Xcode Release archive, exported and validated the IPA, and uploaded Deadfront `0.2.0 (202609231330)` to App Store Connect. Delivery UUID: `e4055c60-746c-4c6c-9827-835479987fb1`.
- Updated `docs/release/testflight.md` with the signing setup and the correct TestFlight listing. The owner chose Deadfront as the single app to use going forward; the older DurangoLike listing was not updated.
- Documented the simulator's release-library architecture mismatch and added export/run-script guidance so the next Xcode simulator attempt uses the arm64 debug slice.
- Prepared `docs/release/apple-testflight-support-case.md` with the app IDs, delivery UUID, reproduction, validation and account-side checks.

## Evidence

- Xcode reported `ARCHIVE SUCCEEDED` and `EXPORT SUCCEEDED`; Apple's `altool` reported `VERIFY SUCCEEDED with no errors` and `UPLOAD SUCCEEDED with no errors`.
- The extracted IPA has bundle ID `com.deadfront.app`, version `0.2.0 (202609231330)`, a valid code signature, an arm64 executable, and entitlements with `get-task-allow=false` and `beta-reports-active=true`.
- Apple's build upload API recognized the new delivery under Deadfront and reported `PROCESSING` with zero warnings and zero errors immediately after upload.
- The existing Deadfront internal group `Test` has access to all builds and one accepted tester. The accepted tester email matches the accepted tester for the older DurangoLike app. No phone is connected to this Mac, so the new build's install could not be tested on the owner's iPhone here.
- `tools/smoke.sh` printed `SMOKE PASS`. `bash -n tools/release_ios.sh` and `git diff --check` passed.

## What failed or remains unknown

- The owner's phone displayed `The requested app is not available or doesn't exist` and `Try again later` when installing DurangoLike `0.2.0 (202609212254)` from TestFlight. That build was valid, unexpired, assigned to an internal group, and visible as compatible with the iPhone. The same problem was reported for Deadfront. These facts do not establish that the previous debug export caused the download failure.
- App Store Connect marked the new Deadfront build `VALID` and `IN_BETA_TESTING`, and it appeared in the internal `Test` group. The owner tried it on the iPhone and reported the same TestFlight install failure. The phone could not be connected to this Mac for install logs.
- Opening the release-exported Xcode project and building for an arm64 simulator failed with `Undefined symbol: _main`: the official Godot release simulator library is x86_64 only. Running `tools/sim_run.sh` regenerated a debug project with the locally built arm64 simulator slice; the Xcode simulator build then succeeded and the app launched to its sign-in shell. The submitted iPhone device archive had already built successfully with its own arm64 library.
- [Apple Developer Forums](https://developer.apple.com/forums/thread/841482) include the exact error across multiple apps in one account; an Apple App Store Connect engineer called one such case account-specific and directed the developer to contact support with app IDs and team ID. This is evidence of a possible Apple account-side cause, not proof of this account's cause.

## Credits spent

- Meshy: 0.

## What the next agent needs

1. Capture the on-device TestFlight install log when the owner's iPhone can connect to a Mac. Check whether the install-data request fails before package download or whether `installd` rejects the package.
2. Confirm the phone's TestFlight Apple Account matches the accepted tester. If it does, ask Apple Developer Support to investigate the account's TestFlight delivery state. Deadfront App ID `6814673196`; DurangoLike App ID `6813273331`; team ID `U6SV8Z7K4S`.
