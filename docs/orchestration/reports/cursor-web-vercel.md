# Cursor web / Vercel

Plan D2 said no web export in v1. The owner asked to publish as a website on Vercel anyway.

## Live URL

**https://durango-like.vercel.app**

Project: `mikiagents-projects/durango-like` (Hobby). Inspect: https://vercel.com/mikiagents-projects/durango-like

Verified in Chromium: WASM `application/wasm`, pack parts download, splash then the island HUD (`fps 120`, MAP/CRAFT/BAG). Screenshot: `docs/orchestration/reports/cursor-web-vercel.png`.

## What shipped

- Web export preset (Compatibility, **no threads**, PWA, landscape, experimental virtual keyboard). Output lives at repo-root `export/web/` (gitignored) so Godot does not import the WASM/PCK.
- `tools/install_web_templates.sh` — standard (non-Mono) Godot 4.7.1 app at `~/Applications/Godot-4.7.1.app` plus official `web_nothreads_*.zip` templates. The Mono editor **refuses** HTML5 export even for this GDScript-only project.
- `tools/export_web.sh` — `--export-release Web` then `tools/web_pack_for_vercel.py`.
- `tools/deploy_web.sh` — export + `vercel deploy --prod`. `--preview` skips production alias.
- `hosting/web/vercel.json` — wasm MIME, short cache on `index.html` / `pack.manifest.json`.

## Why the pack is split

`index.pck` is **226.5 MB**. Vercel Hobby caps a single file at **100 MB**. The packer splits it into `pack.00.bin` / `pack.01.bin` / `pack.02.bin` (90+90+46.5 MB) and the HTML concatenates them in the browser as `index.pck` before `Engine.start()`. Do not connect this Git repo to Vercel auto-deploy: Vercel cannot run Godot.

## How to ship an update

```
tools/install_web_templates.sh   # once per machine
tools/deploy_web.sh              # export + production
tools/deploy_web.sh --preview    # unique URL
```

iOS still uses `Godot_mono.app` + `tools/release_ios.sh`. Web must use `GODOT_WEB_PATH` / the standard editor.

## Smoke

`tools/smoke.sh --no-import` → `SMOKE PASS`

## Assumptions

- Single-thread web export (no COOP/COEP). Fine on Hobby; slower than a threaded build.
- Web uses the Compatibility renderer (`rendering_method.web=gl_compatibility`, MSAA off). First load is ~265 MB (wasm gzipes to ~9 MB on the wire; pack parts do not).
- `# ASSUMPTION:` do not `vercel git connect` the monorepo. Deploy the pre-exported `export/web` folder with the CLI.

## Credits spent

0 (no Meshy).

## Next

Owner: open https://durango-like.vercel.app on a phone (Chrome/Firefox; Safari WebGL 2 is weaker). Native iOS remains TestFlight. Web is a share link, not a replacement for the phone build.
