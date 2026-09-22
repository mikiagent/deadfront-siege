# World readability pass

Base: `8ab0f16` (`main` at task start)

## Shipped

- World label pills now stay hidden beyond 8 m and fade in from 8 m to 5.5 m; an actively inspected/gathered node remains visible.
- Home camp terrain gets a broad, warm trampled clearing and subtle path variation instead of one flat grass field.
- Claim boundaries changed from dense, opaque cyan dashes to sparse, low-alpha earth-tone marks.
- Temperate palette now uses deeper green grass, warmer sand/dirt, and darker rocks for better phone-scale value separation.
- Survivor rig is 18% larger. Its beacon is smaller, dimmer, and lower-alpha so the model carries more of the visual read.

## Validation

- `git diff --check`: clean.
- Godot 4.7.1 import completed without GDScript parse errors.
- `tools/smoke.sh`: `SMOKE PASS`.
- `tools/test.sh`: `[tests] PASS` (the suite intentionally logs the existing newer-save-schema guard while passing).

## Visual verification blocker

Tried to render the island lab at an explicit 844x390 viewport under local Linux software rendering. The project loaded, but the island scene did not finish in a usable capture window, so no trustworthy after screenshot was produced. The former public GitHub Pages URL currently returns a GitHub Pages 404 at the same 844x390 viewport, so it could not provide a before frame either. No deployment was made.
