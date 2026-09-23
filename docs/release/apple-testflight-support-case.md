# Apple Developer Support case: TestFlight installs fail for both app records

**Team ID:** `U6SV8Z7K4S`

**Apps:**

- Deadfront — App Store Connect App ID `6814673196`, bundle ID `com.deadfront.app`.
- DurangoLike — App Store Connect App ID `6813273331`, bundle ID `com.durangolike.dev`. These records represent the same game; we plan to use Deadfront going forward.

**Problem:** An accepted internal tester can see both apps and their builds in TestFlight on an iPhone, but tapping Install fails. The phone reports either “Could not install [app]. The requested app is not available or doesn’t exist” or “Could not install [app]. Try again later.” The app does not reach launch.

**Fresh reproduction:** On September 23, 2026, we exported Godot 4.7.1 in release mode and used Xcode 27 to create a signed iOS device archive for Deadfront `0.2.0 (202609231330)`. `xcodebuild archive` and `-exportArchive` succeeded; `altool --validate-app` reported `VERIFY SUCCEEDED with no errors`; `altool --upload-app` reported `UPLOAD SUCCEEDED with no errors`. Delivery UUID: `e4055c60-746c-4c6c-9827-835479987fb1`.

App Store Connect reports this new build as `VALID` and `IN_BETA_TESTING`. The internal group `Test` has access to all builds, including this one, and contains one `ACCEPTED` tester. The tester tried the new Deadfront build and received the same install error. The older DurangoLike build `0.2.0 (202609212254)` also shows as valid, unexpired, in beta testing, and assigned to its internal group, but it fails to install with the same error.

The fresh IPA contains an arm64 executable and bundle ID `com.deadfront.app`. Its signature verifies locally; the embedded App Store profile has application identifier `U6SV8Z7K4S.com.deadfront.app` and `get-task-allow=false`. The phone's TestFlight page marks the older build compatible with the iPhone. We can provide the iPhone screenshots and the upload/validation logs.

**Request:** Please investigate this team's TestFlight install-data and binary-delivery state, including any beta contract or account-level availability problem, for both App IDs. Please provide the specific server or device error and restore installability. Uploading a newly signed, validated release build did not change the failure.

**Before sending:** Confirm the phone's TestFlight Apple Account matches the accepted tester and attach the latest Deadfront phone screenshot. An on-device install log is not yet available because the iPhone cannot currently connect to the Mac.
