#!/usr/bin/env bash
# Publish a game build for the downloader shell: export core + assets packs, upload the
# ones whose hash changed to Vercel Blob, write hosting/builds/manifest.json and deploy the
# manifest endpoint. Testers' apps pick the build up on next sign-in.
# Usage: tools/publish_pck.sh                 (upload + deploy)
#        tools/publish_pck.sh --local DIR PORT (write packs + manifest into DIR for tools/shell_test.sh)
# Needs tools/blob.env with BLOB_READ_WRITE_TOKEN=... (gitignored) for the upload path.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
G="${GODOT_PATH:-/Applications/Godot_mono.app/Contents/MacOS/Godot}"
OUT="$ROOT/game/export/packs"
HOSTING="$ROOT/hosting/builds"
PROJECT="${VERCEL_PROJECT:-durango-builds}"
SCOPE="${VERCEL_SCOPE:-mikiagents-projects}"
LOCAL=""; PORT=8765
if [[ "${1:-}" == "--local" ]]; then LOCAL="${2:?dir}"; PORT="${3:-8765}"; fi

sha() { eval "echo \"\$SHA_$1\""; }
sha8() { sha "$1" | cut -c1-8; }
sz() { eval "echo \"\$SIZE_$1\""; }

VER="$(date +%Y%m%d.%H%M)-$(git -C "$ROOT" rev-parse --short HEAD)"
echo "$VER" > "$ROOT/game/shell/build_version.txt"
mkdir -p "$OUT"
for name in core assets; do
  preset="PackCore"; [[ "$name" == "assets" ]] && preset="PackAssets"
  echo "== export $preset"
  perl -e 'alarm 1800; exec @ARGV' "$G" --headless --path "$ROOT/game" --export-pack "$preset" "export/packs/$name.pck" >/dev/null 2>&1 || true
  [[ -s "$OUT/$name.pck" ]] || { echo "export of $name failed"; exit 1; }
  eval "SHA_$name=\"$(shasum -a 256 "$OUT/$name.pck" | cut -c1-64)\""
  eval "SIZE_$name=\"$(stat -f%z "$OUT/$name.pck")\""
  echo "   $name $(sz $name) bytes sha $(sha8 $name)"
done

write_manifest() { # $1 = out file, $2 = core url, $3 = assets url
  python3 - "$1" "$VER" "$2" "$SHA_core" "$SIZE_core" "$3" "$SHA_assets" "$SIZE_assets" <<'PY'
import json, sys
out, ver, cu, cs, cz, au, as_, az = sys.argv[1:]
m = {"version": ver, "min_shell": 1, "channel": "dev",
     "packs": [  # assets first so core (scripts, data) wins on any overlap
        {"name": "assets", "url": au, "sha256": as_, "size": int(az)},
        {"name": "core", "url": cu, "sha256": cs, "size": int(cz)}]}
json.dump(m, open(out, "w"), indent=2)
PY
}

if [[ -n "$LOCAL" ]]; then
  mkdir -p "$LOCAL/api"
  for name in core assets; do cp "$OUT/$name.pck" "$LOCAL/$name-$(sha8 $name).pck"; done
  write_manifest "$LOCAL/manifest.json" "http://127.0.0.1:$PORT/core-$(sha8 core).pck" "http://127.0.0.1:$PORT/assets-$(sha8 assets).pck"
  cp "$LOCAL/manifest.json" "$LOCAL/api/manifest"
  echo "local build $VER in $LOCAL"
  exit 0
fi

# shellcheck disable=SC1091
[[ -f "$ROOT/tools/blob.env" ]] && source "$ROOT/tools/blob.env"
: "${BLOB_READ_WRITE_TOKEN:?set BLOB_READ_WRITE_TOKEN in tools/blob.env}"
prev_url() { python3 -c "
import json,sys
try:
  m=json.load(open('$HOSTING/manifest.json'))
  for p in m.get('packs',[]):
    if p['name']==sys.argv[1] and p['sha256']==sys.argv[2]: print(p['url'])
except Exception: pass" "$1" "$2"; }
for name in core assets; do
  url="$(prev_url "$name" "$(sha $name)")"
  if [[ -n "$url" ]]; then echo "== $name unchanged, keeping $url"; eval "URL_$name=\"$url\""; continue; fi
  echo "== upload $name"
  log="$(npx --yes vercel blob put "$OUT/$name.pck" --pathname "builds/$name-$(sha8 $name).pck" --access public --rw-token "$BLOB_READ_WRITE_TOKEN" --content-type application/octet-stream 2>&1 || true)"
  url="$(echo "$log" | grep -oE 'https://[A-Za-z0-9./_-]+\.pck' | head -1)"
  [[ -n "$url" ]] || { echo "$log"; echo "no blob URL for $name"; exit 1; }
  eval "URL_$name=\"$url\""
  echo "   $url"
done
write_manifest "$HOSTING/manifest.json" "$URL_core" "$URL_assets"
echo "== deploy manifest ($VER)"
(cd "$HOSTING" && npx --yes vercel deploy --yes --prod --project "$PROJECT" --scope "$SCOPE" 2>&1 | tail -3)
# Prune packs the new manifest no longer references (Hobby Blob is capped at 1 GB).
keep="$URL_core $URL_assets"
for u in $(npx --yes vercel blob list --rw-token "$BLOB_READ_WRITE_TOKEN" 2>/dev/null | grep -oE 'https://[^ ]+\.pck'); do
  case " $keep " in *" $u "*) ;; *) npx --yes vercel blob del "$u" --rw-token "$BLOB_READ_WRITE_TOKEN" --non-interactive >/dev/null 2>&1 && echo "   pruned $u";; esac
done
echo "published $VER"
