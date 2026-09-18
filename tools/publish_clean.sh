#!/usr/bin/env bash
# Publish packs from a clean checkout of HEAD (or a given ref), so half-finished edits in
# the working tree (e.g. a Cursor milestone in progress) never ship to testers.
# Usage: tools/publish_clean.sh [ref]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="${1:-HEAD}"
WT="${PUBLISH_WORKTREE:-$HOME/Library/Caches/durango-publish}"
rm -rf "$WT"; git -C "$ROOT" worktree prune
git -C "$ROOT" worktree add --detach "$WT" "$REF" >/dev/null
# Reuse the import cache (APFS clone) so the export does not re-import 600 MB of assets.
[[ -d "$ROOT/game/.godot" ]] && cp -Rc "$ROOT/game/.godot" "$WT/game/.godot"
cp "$ROOT/tools/blob.env" "$WT/tools/blob.env"
mkdir -p "$WT/hosting/builds"; cp -R "$ROOT/hosting/builds/.vercel" "$WT/hosting/builds/.vercel"
cp "$ROOT/hosting/builds/manifest.json" "$WT/hosting/builds/manifest.json"   # lets unchanged packs reuse their URLs
"$WT/tools/publish_pck.sh"
cp "$WT/hosting/builds/manifest.json" "$ROOT/hosting/builds/manifest.json"
cp "$WT/game/shell/build_version.txt" "$ROOT/game/shell/build_version.txt"
git -C "$ROOT" worktree remove --force "$WT"
echo "published $(git -C "$ROOT" rev-parse --short "$REF"); manifest copied back (commit hosting/builds/manifest.json)"
