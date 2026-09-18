#!/usr/bin/env bash
# Export the Godot web build, then publish export/web as a Vercel static site.
# Usage: tools/deploy_web.sh [--preview]
#   --preview  skip --prod (unique URL, not the production alias)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/export/web"
PROD=1
if [[ "${1:-}" == "--preview" ]]; then
  PROD=0
fi
"$ROOT/tools/export_web.sh"
if [[ ! -f "$OUT/index.html" ]]; then
  echo "export produced no index.html"
  exit 1
fi
PROJECT="${VERCEL_PROJECT:-durango-like}"
SCOPE="${VERCEL_SCOPE:-mikiagents-projects}"
if ! npx --yes vercel project inspect "$PROJECT" --scope "$SCOPE" >/dev/null 2>&1; then
  echo "Creating Vercel project $PROJECT"
  npx --yes vercel project add "$PROJECT" --scope "$SCOPE"
fi
ARGS=(deploy "$OUT" --yes --project "$PROJECT" --scope "$SCOPE" --archive=tgz)
if [[ "$PROD" == "1" ]]; then
  ARGS+=(--prod)
fi
echo "Deploying $OUT to Vercel project $PROJECT (prod=$PROD)"
npx --yes vercel "${ARGS[@]}"
