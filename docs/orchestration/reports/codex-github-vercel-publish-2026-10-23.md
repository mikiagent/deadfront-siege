# GitHub and Vercel publish, 2026-10-23

Agent: Codex

## What shipped

- Pushed `claude/mmo-overhaul` to GitHub at commit `89f30ad1663d7d53af07d86ca05f5c2f26f3a11d`.
- Exported the Godot 4.7.1 `Web` release and deployed it to Vercel production.
- Production alias: <https://durango-like.vercel.app>
- Immutable deployment: <https://durango-like-3211a9d56-mikiagents-projects.vercel.app>
- Vercel inspection: <https://vercel.com/mikiagents-projects/durango-like/AJ9pYGtCj31XA1wkUVv3J1ox1k9W>
- Deployed build stamp: `89f30ad16/9c16f17a75`.

## Verification

- `tools/deploy_web.sh`: PASS. Vercel reported the production deployment ready and applied the alias.
- Production `index.html`: PASS. It contains build stamp `89f30ad16/9c16f17a75`.
- Production pack manifest: PASS. It declares 20 parts totaling 322,539,748 bytes.
- Production `index.wasm`: HTTP 200 with `Content-Type: application/wasm`.
- First and last pack parts: HTTP 200 with immutable caching and expected sizes.
- Browser boot against the same exported files: PASS. The loader assembled all 20 parts, Godot printed `[boot] main scene ready`, and the 1600 by 900 canvas contained a rendered frame.
- `tools/smoke.sh`: `SMOKE PASS`.
- GitHub remote branch: PASS. `origin/claude/mmo-overhaul` resolves to `89f30ad1663d7d53af07d86ca05f5c2f26f3a11d` before this report-only commit.

## Notes

- Vercel's 100% usage indicator did not block this deployment.
- Vercel Authentication remains enabled. Anonymous visitors may see the Vercel login screen. Verification of protected production files used `vercel curl`.
- The exported web payload is still large. The PCK is about 307.6 MiB before chunking, so first load remains a mobile risk.

## What failed

- Nothing in the GitHub push, web export, production deployment, or smoke check failed.
- A full gameplay route was not run against the protected production URL. The exact stamped export completed a browser boot locally, and production file checks matched that export.

## Credits spent

- Meshy: 0.
- Tripo: 0.

## What the next agent needs

- Deploy future updates with `tools/deploy_web.sh`; do not connect the repository root to Vercel auto-deploy.
- Keep the chunked pack loader until every deployment file is below Vercel's per-file limit.
- Decide whether the production alias should remain behind Vercel Authentication before sharing it publicly.
