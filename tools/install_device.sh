#!/usr/bin/env bash
# Install the app straight onto a USB-connected iPhone with a development signature,
# bypassing TestFlight. Registers the device with the team automatically (API key auth).
# Usage: tools/install_device.sh [--no-export]
# Needs: phone plugged in and trusted, tools/release.env, the App Store Connect API key.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/release.env"
OUT="$ROOT/game/export/ios"
WORK="${DEV_WORK:-$HOME/Library/Caches/durango-device}"; mkdir -p "$WORK"
KEY="$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"
[[ "${1:-}" == "--no-export" ]] || "$ROOT/tools/export_ios.sh"
UDID="$(xcrun devicectl list devices 2>/dev/null | grep -v simulated | grep -E 'connected|available' | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1 || true)"
[[ -n "$UDID" ]] || { echo "No iPhone connected over USB (xcrun devicectl list devices). Plug it in, tap Trust, retry."; exit 1; }
echo "== device $UDID"
xcodebuild -project "$OUT/durango.xcodeproj" -scheme durango -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$WORK/dd" \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  -authenticationKeyPath "$KEY" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic build 2>&1 | grep -E 'error:|warning: .*provision|BUILD (SUCCEEDED|FAILED)' || true
APP="$WORK/dd/Build/Products/Debug-iphoneos/durango.app"
[[ -d "$APP" ]] || { echo "build failed (no $APP)"; exit 1; }
xcrun devicectl device install app --device "$UDID" "$APP"
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || true
echo "installed and launched $BUNDLE_ID on $UDID"
