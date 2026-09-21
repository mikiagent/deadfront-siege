#!/usr/bin/env bash
# Build the game and push it to TestFlight. Usage:
#   tools/release_ios.sh                 # export from Godot, archive, sign, upload
#   tools/release_ios.sh --no-export     # reuse game/export/ios (skip the Godot export)
#   tools/release_ios.sh --validate      # everything except the upload
# Credentials: the App Store Connect API key file lives at
#   ~/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8   (never in the repo)
# Key ID and Issuer ID are not secrets and live in tools/release.env.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/release.env"
G="${GODOT_PATH:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
OUT="$ROOT/game/export/ios"
WORK="${RELEASE_WORK:-$HOME/Library/Caches/durango-release}"
mkdir -p "$WORK"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"   # unique, increasing; TestFlight needs each upload to be higher
DO_EXPORT=1; DO_UPLOAD=1
for a in "$@"; do case "$a" in --no-export) DO_EXPORT=0;; --validate) DO_UPLOAD=0;; esac; done

if [[ $DO_EXPORT -eq 1 ]]; then
  echo "== 1/5 Godot export → $OUT"
  "$ROOT/tools/export_ios.sh"           # writes the Xcode project and strips the aps-environment entitlement
fi
# Godot rewrites Info.plist on export; make sure the encryption-exemption key is present (avoids the compliance prompt).
python3 - "$OUT/durango/durango-Info.plist" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text()
if "ITSAppUsesNonExemptEncryption" not in s:
    p.write_text(s.replace("</dict>\n</plist>", "\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>\n</dict>\n</plist>", 1)); print("   added ITSAppUsesNonExemptEncryption=false")
PY

echo "== 2/5 Archive (Release, automatic signing, build $BUILD_NUMBER)"
rm -rf "$WORK/durango.xcarchive"
xcodebuild -project "$OUT/durango.xcodeproj" -scheme durango -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$WORK/durango.xcarchive" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  CODE_SIGN_IDENTITY="Apple Development" MARKETING_VERSION="$MARKETING_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  archive 2>&1 | tee "$WORK/archive.log"
[[ -d "$WORK/durango.xcarchive" ]] || { echo "archive missing"; exit 1; }

echo "== 3/5 Export signed IPA"
cat > "$WORK/exportOptions.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>export</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PL
rm -rf "$WORK/ipa"
xcodebuild -exportArchive -archivePath "$WORK/durango.xcarchive" -exportOptionsPlist "$WORK/exportOptions.plist" \
  -exportPath "$WORK/ipa" -allowProvisioningUpdates 2>&1 | grep -E 'error|EXPORT (SUCCEEDED|FAILED)' || true
IPA="$WORK/ipa/durango.ipa"; [[ -f "$IPA" ]] || { echo "IPA missing"; exit 1; }
ls -la "$IPA"

echo "== 4/5 Validate"
xcrun altool --validate-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | grep -E 'VERIFY|error' || true

if [[ $DO_UPLOAD -eq 1 ]]; then
  echo "== 5/5 Upload to App Store Connect (TestFlight)"
  xcrun altool --upload-app -f "$IPA" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" 2>&1 | grep -E 'UPLOAD|Delivery|error' || true
  echo "Uploaded build $MARKETING_VERSION ($BUILD_NUMBER). Processing takes ~10 min, then it appears under TestFlight in App Store Connect."
fi
